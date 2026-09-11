# ATC Radio-to-Text, Umsetzungsplan

Technischer Plan mit den geprueften API-Aufrufen und dem Datenmodell.

## Pipeline, dreistufig, alles on-device

### 1. Audio-Capture (Modul A)

- `AVAudioSession` im Modus `.measurement`, Kategorie `.record`, kein VoIP.
- USB-Port als bevorzugter Eingang ueber `setPreferredInput`.
- Tap der `AVAudioEngine` auf dem Input-Node.
- 30-Sekunden-Ringpuffer, damit ein Segment nach einem Rufzeichen-Treffer
  rueckwirkend an Whisper gegeben werden kann (Phase 1).

### 2. Transkription, zweischichtig (Modul B)

- Schicht 1, Dauerbetrieb, guenstig: SpeechDetector als VAD plus SpeechAnalyzer
  mit en-Locale. Grobes Transkript nur fuer das Rufzeichen-Spotting.
- Schicht 2, getriggert, genau: WhisperKit mehrsprachig mit Auto-Erkennung.
  Laeuft erst nach einem Rufzeichen-Treffer ueber das gepufferte Segment und
  liefert das finale Transkript.
- Grund fuer zwei Schichten: Apples SpeechTranscriber ist locale-gebunden und
  kann Sprachwechsel schlecht. Whisper im Dauerbetrieb waere thermisch zu teuer.

### 3. Struktur und IFR/VFR-Klassifikation (Modul D)

- Foundation Models mit `@Generable` auf dem finalen Transkript.

## Gepruefte iOS-26-API (Speech-Framework)

Diese Signaturen wurden gegen die Framework-Interfaces geprueft. Sie sind neu in
iOS 26 und weichen teils vom ersten Skelett ab.

### SpeechAnalyzer

- Initialisierer: `init(modules: [any SpeechModule], options: SpeechAnalyzer.Options?)`.
  Ein reiner `init(modules:)` existiert nicht. In Phase 0 wird
  `SpeechAnalyzer(modules: [transcriber], options: nil)` genutzt.
- Start im autonomen Modus: `func start<InputSequence>(inputSequence: InputSequence) async throws`,
  wobei `InputSequence.Element == AnalyzerInput`.
- Bestes Format: `static func bestAvailableAudioFormat(compatibleWith: [any SpeechModule]) async -> AVAudioFormat?`.
- Abschluss: `func finalizeAndFinishThroughEndOfInput() async throws`.

### SpeechTranscriber

- Initialisierer: `init(locale:transcriptionOptions:reportingOptions:attributeOptions:)`
  oder `init(locale:preset:)`. Ein reiner `init(locale:)` existiert nicht.
- Ergebnisse: `var results: some AsyncSequence<SpeechTranscriber.Result, any Error>`.
- Ergebnisfelder: `text: AttributedString`, `isFinal: Bool`, `range: CMTimeRange`,
  `alternatives: [AttributedString]`.
- Reporting-Optionen: `.volatileResults`, `.fastResults`, `.alternativeTranscriptions`.
- Locale-Pruefung: `static var installedLocales: [Locale]`,
  `static var supportedLocales: [Locale]`,
  `static func supportedLocale(equivalentTo: Locale) async -> Locale?` (async).

### AnalyzerInput

- `init(buffer: AVAudioPCMBuffer)` und `init(buffer:bufferStartTime:)`.

### AssetInventory und AssetInstallationRequest

- `static func assetInstallationRequest(supporting: [any SpeechModule]) async throws -> AssetInstallationRequest?`.
- Download und Installation ueber `func downloadAndInstall() async throws`.
- Dies ist die einzige Stelle mit moeglichem Netzwerkzugriff. Sie laeuft einmalig
  am Boden vor dem Einsatz, nicht im Verarbeitungspfad.

## Fallstricke

- Das Long-Form-Modell des SpeechTranscriber nimmt kein eigenes Vokabular
  (keine Contextual Strings). Deshalb liefert Whisper das finale Transkript,
  nicht Apple.
- Der USB-Audio-Eingang erscheint nicht immer zuverlaessig in Drittanbieter-Apps.
  Auf echtem Geraet verifizieren.
- Ohne Modus `.measurement` verbiegt Apples Sprach-DSP den bandbegrenzten Funk.
- ATC-Funk ist verrauscht und bandbegrenzt. Ausbaupfad: ATC-Fine-Tune fuer
  Whisper mit ATCO2 oder ATCOSIM.

## Datenmodell (Phase 1, SwiftData)

Skizze fuer die spaetere Persistenz, in Phase 0 noch nicht umgesetzt.

- `Uebermittlung`: eine erkannte Funkuebermittlung.
  - `id`, `zeitpunkt`, `dauer`.
  - `audioDateiPfad`: Verweis auf die Aufnahme.
  - `transkript`: finaler Text aus Whisper.
  - `sprecher`: Pilot oder ATC.
  - `flugregel`: IFR oder VFR, aus der Klassifikation.
  - `rufzeichenTreffer`: ob und wie das eigene Rufzeichen erkannt wurde.
- `Konversation`: Gruppierung mehrerer Uebermittlungen ueber ein Zeitfenster.
- `Rufzeichenprofil`: Voll- und Kurzformen des eigenen Rufzeichens fuer den
  Matcher.

## Naechste Schritte nach Phase 0

1. Rufzeichen-Konfiguration plus fuzzy phonetischer Matcher mit
   Konversationsfenster (Modul C).
2. WhisperKit integrieren, getriggert nach Rufzeichen-Treffer (Modul B Schicht 2).
3. Foundation-Models-Klassifikation IFR/VFR (Modul D).
4. SwiftData-Persistenz plus IFR/VFR-gruppierte UI (Modul E).
