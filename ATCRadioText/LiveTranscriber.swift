import Foundation
import Observation
import AVFoundation
import Speech

/// Phase 0: Live-Transkription als Machbarkeitsnachweis.
///
/// Aufgabe dieser Klasse:
/// 1. AVAudioSession auf Aufnahme im Modus `.measurement` konfigurieren und den
///    USB-Audio-Eingang bevorzugen (Klinke zu USB-C Adapter).
/// 2. Den Audio-Tap der AVAudioEngine an Apples SpeechAnalyzer (neu in iOS 26)
///    weiterreichen und ein grobes Live-Transkript erzeugen.
///
/// Diese Schicht dient nur dem Spotting und der Sichtpruefung. Das genaue,
/// mehrsprachige Transkript liefert spaeter WhisperKit (Phase 1, hier nicht
/// enthalten).
///
/// Kein Netzwerkcode im Verarbeitungspfad. Einzige Ausnahme ist die einmalige
/// Bereitstellung des Apple-Sprachmodells ueber `AssetInventory`, siehe
/// `modellSicherstellen(fuer:locale:)`. Diese laeuft am Boden vor dem Einsatz
/// und nicht waehrend der Verarbeitung.
@MainActor
@Observable
final class LiveTranscriber {

    // MARK: Sichtbarer Zustand fuer die UI

    /// Verkettete, endgueltige Transkriptteile.
    private(set) var transkript: String = ""
    /// Aktuell laufender, noch vorlaeufiger Teil.
    private(set) var teilTranskript: String = ""
    /// Spitzenpegel des Eingangs, 0 bis 1, fuer die Pegelanzeige.
    private(set) var eingangsPegel: Float = 0
    /// Name des aktiven Audio-Eingangs.
    private(set) var eingangsName: String = "unbekannt"
    /// Ob die Aufnahme laeuft.
    private(set) var laeuft: Bool = false
    /// Kurzer Statustext fuer die UI.
    private(set) var statusText: String = "bereit"

    // MARK: Audio und Transkription

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var analyzerFormat: AVAudioFormat?

    /// Eingabestrom, aus dem der Analyzer die Audiodaten zieht.
    private var eingabeFortsetzung: AsyncStream<AnalyzerInput>.Continuation?
    /// Aufgabe, die die Ergebnisse des Transcribers konsumiert.
    private var ergebnisAufgabe: Task<Void, Never>?

    /// Locale fuer Schicht 1 (grobes Spotting). Phase 0 nutzt Englisch.
    private let locale = Locale(identifier: "en-US")

    // MARK: Steuerung

    func start() async {
        guard !laeuft else { return }
        do {
            try await berechtigungPruefen()
            try konfiguriereSession()
            try await starteTranskription()
            try starteAudioEngine()
            laeuft = true
            statusText = "laeuft"
        } catch {
            statusText = "Fehler: \(error.localizedDescription)"
            await stop()
        }
    }

    func stop() async {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        eingabeFortsetzung?.finish()
        eingabeFortsetzung = nil

        if let analyzer {
            // Verbleibende Audiodaten abschliessen und den Analyzer beenden.
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        ergebnisAufgabe?.cancel()
        ergebnisAufgabe = nil

        analyzer = nil
        transcriber = nil
        analyzerFormat = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        eingangsPegel = 0
        laeuft = false
        statusText = "gestoppt"
    }

    // MARK: Berechtigung

    private func berechtigungPruefen() async throws {
        // Ab iOS 17 loest AVAudioApplication die alte AVAudioSession-Abfrage ab.
        let erlaubt = await withCheckedContinuation { fortsetzung in
            AVAudioApplication.requestRecordPermission { ok in
                fortsetzung.resume(returning: ok)
            }
        }
        guard erlaubt else { throw LiveTranscriberFehler.mikrofonAbgelehnt }
    }

    // MARK: Audio-Session

    private func konfiguriereSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Aufnahme-Kategorie, kein VoIP. Modus .measurement, damit Apples
        // Sprach-DSP den bandbegrenzten Funk nicht verbiegt.
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // USB-Audio als Eingang bevorzugen, falls angeschlossen.
        if let usb = session.availableInputs?.first(where: { $0.portType == .usbAudio }) {
            try session.setPreferredInput(usb)
            eingangsName = usb.portName
        } else {
            eingangsName = session.currentRoute.inputs.first?.portName ?? "kein Eingang"
        }
    }

    // MARK: Transkription vorbereiten

    private func starteTranskription() async throws {
        // Passende, unterstuetzte Locale ermitteln.
        guard let unterstuetzt = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw LiveTranscriberFehler.localeNichtUnterstuetzt
        }

        // Transcriber mit vorlaeufigen Ergebnissen fuer eine lebendige Anzeige.
        let transcriber = SpeechTranscriber(
            locale: unterstuetzt,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        try await modellSicherstellen(fuer: transcriber, locale: unterstuetzt)

        // SpeechAnalyzer verlangt das Argument options, hier ohne Sonderoptionen.
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: nil)
        self.analyzer = analyzer

        // Bestes Audioformat, das die Module akzeptieren.
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        // Eingabestrom, in den der Audio-Tap die Puffer schreibt.
        let (strom, fortsetzung) = AsyncStream<AnalyzerInput>.makeStream()
        eingabeFortsetzung = fortsetzung

        // Ergebnisse laufend konsumieren. Der Task erbt den MainActor.
        ergebnisAufgabe = Task { [weak self] in
            guard let self else { return }
            do {
                for try await ergebnis in transcriber.results {
                    let text = String(ergebnis.text.characters)
                    self.verarbeiteErgebnis(text: text, endgueltig: ergebnis.isFinal)
                }
            } catch {
                self.statusText = "Ergebnisfehler: \(error.localizedDescription)"
            }
        }

        // Analyzer im autonomen Modus starten, er zieht aus dem Strom.
        try await analyzer.start(inputSequence: strom)
    }

    /// Stellt sicher, dass das Apple-Sprachmodell fuer die Locale installiert ist.
    ///
    /// Achtung: Ist das Modell noch nicht vorhanden, laedt das System es einmalig
    /// nach. Das ist der einzige Punkt mit moeglichem Netzwerkzugriff und laeuft
    /// bewusst am Boden vor dem Einsatz, nicht im Verarbeitungspfad.
    private func modellSicherstellen(fuer transcriber: SpeechTranscriber, locale: Locale) async throws {
        let installiert = await SpeechTranscriber.installedLocales
        let vorhanden = installiert.contains { $0.identifier(.bcp47) == locale.identifier(.bcp47) }
        if vorhanden { return }

        if let anfrage = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            statusText = "lade Sprachmodell"
            try await anfrage.downloadAndInstall()
        }
    }

    // MARK: Audio-Engine und Tap

    private func starteAudioEngine() throws {
        let eingang = audioEngine.inputNode
        let hardwareFormat = eingang.inputFormat(forBus: 0)
        let zielFormat = analyzerFormat

        // Konverter nur anlegen, wenn Hardware- und Zielformat abweichen.
        let konverter: AVAudioConverter? = {
            guard let zielFormat, zielFormat != hardwareFormat else { return nil }
            return AVAudioConverter(from: hardwareFormat, to: zielFormat)
        }()

        // Lokale Kopie der Fortsetzung, damit der Tap nicht auf den MainActor greift.
        let fortsetzung = eingabeFortsetzung

        eingang.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { puffer, _ in
            // Pegel fuer die Anzeige auf dem MainActor aktualisieren.
            let pegel = Self.spitzenPegel(puffer)
            Task { @MainActor [weak self] in
                self?.eingangsPegel = pegel
            }

            // Audio an den Analyzer geben, bei Bedarf ins Zielformat wandeln.
            if let ausgabe = Self.konvertiere(puffer, mit: konverter, ziel: zielFormat) {
                fortsetzung?.yield(AnalyzerInput(buffer: ausgabe))
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: Ergebnisverarbeitung

    private func verarbeiteErgebnis(text: String, endgueltig: Bool) {
        if endgueltig {
            transkript += transkript.isEmpty ? text : " " + text
            teilTranskript = ""
        } else {
            teilTranskript = text
        }
    }

    // MARK: Hilfsfunktionen (nonisolated, laufen auf dem Audio-Thread)

    /// Wandelt einen Puffer bei Bedarf ins Zielformat. Ist kein Konverter noetig,
    /// wird der Eingabepuffer unveraendert zurueckgegeben.
    private static func konvertiere(
        _ eingabe: AVAudioPCMBuffer,
        mit konverter: AVAudioConverter?,
        ziel: AVAudioFormat?
    ) -> AVAudioPCMBuffer? {
        guard let konverter, let ziel else { return eingabe }

        let verhaeltnis = ziel.sampleRate / eingabe.format.sampleRate
        let kapazitaet = AVAudioFrameCount(Double(eingabe.frameLength) * verhaeltnis) + 1024
        guard let ausgabe = AVAudioPCMBuffer(pcmFormat: ziel, frameCapacity: kapazitaet) else {
            return nil
        }

        var geliefert = false
        var fehler: NSError?
        _ = konverter.convert(to: ausgabe, error: &fehler) { _, status in
            if geliefert {
                status.pointee = .noDataNow
                return nil
            }
            geliefert = true
            status.pointee = .haveData
            return eingabe
        }

        if fehler != nil { return nil }
        return ausgabe
    }

    /// Grober Spitzenpegel des ersten Kanals, 0 bis 1.
    private static func spitzenPegel(_ puffer: AVAudioPCMBuffer) -> Float {
        guard let kanaele = puffer.floatChannelData else { return 0 }
        let kanal = kanaele[0]
        let anzahl = Int(puffer.frameLength)
        var spitze: Float = 0
        for i in 0..<anzahl {
            spitze = max(spitze, abs(kanal[i]))
        }
        return min(spitze, 1)
    }
}

/// Fehlerfaelle der Phase-0-Transkription.
enum LiveTranscriberFehler: LocalizedError {
    case mikrofonAbgelehnt
    case localeNichtUnterstuetzt

    var errorDescription: String? {
        switch self {
        case .mikrofonAbgelehnt:
            return "Mikrofonzugriff wurde abgelehnt."
        case .localeNichtUnterstuetzt:
            return "Die gewuenschte Sprache wird nicht unterstuetzt."
        }
    }
}
