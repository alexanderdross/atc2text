# CLAUDE.md

Übergabe-Kontext für Claude Code. Vollständige Details in `docs/`. Diese Datei bewusst kompakt halten, sie wird bei jeder Sitzung geladen.

## Projekt

ATC Radio-to-Text: iOS-App, die ATC-Sprechfunk in lesbaren Text umwandelt. Zeichnet nur auf, wenn der Pilot selbst spricht oder ATC das eigene Rufzeichen nennt. Zwei Outputs: Audioaufnahmen (Voice Recorder) und nach IFR/VFR geclusterte Transkripte.

## Harte Rahmenbedingungen (nicht ohne Rücksprache ändern)

- Zielgerät: iPhone 15 Pro / Pro Max (A17 Pro), iOS 26+, Apple Intelligence vorausgesetzt.
- Vollständig on-device und offline. In der Luft kein Mobilfunk. Kein Netzwerk im Funk- und Verarbeitungspfad, keine Cloud-Aufrufe.
- Sprachen: Deutsch und Englisch, Sprachwechsel innerhalb einer Übermittlung möglich.
- Audio-Eingang: USB-C über class-compliant Klinke-zu-USB-C-Adapter. Nicht das eingebaute Mikrofon.
- Toolchain: Xcode 26+, Swift, SwiftUI, SwiftData.

## Architektur (Kern, mit Begründung)

Dreistufige Pipeline, alles on-device:

1. **Audio-Capture:** AVAudioSession im Modus `.measurement`, USB-Port als bevorzugter Eingang, AVAudioEngine-Tap, 30-Sekunden-Ringpuffer.
2. **Transkription, zweischichtig:**
   - Schicht 1 (Dauerbetrieb, günstig): SpeechDetector (VAD) plus SpeechAnalyzer mit en-Locale, grobes Transkript nur fürs Rufzeichen-Spotting.
   - Schicht 2 (getriggert, genau): WhisperKit mehrsprachig mit Auto-Erkennung, läuft erst nach Rufzeichen-Treffer über das gepufferte Segment, liefert das finale Transkript.
   - Grund für zwei Schichten: Apples SpeechTranscriber ist locale-gebunden und kann Sprachwechsel schlecht. Whisper im Dauerbetrieb wäre thermisch zu teuer. Jede Engine dort, wo sie stark ist.
3. **Struktur und IFR/VFR-Klassifikation:** Foundation Models mit `@Generable` auf dem finalen Transkript.

## Fallstricke (aus Recherche, kosten sonst Zeit)

- SpeechAnalyzer ist neu in iOS 26. Diese Aufrufe vor Nutzung gegen die installierte SDK prüfen statt raten: `analyzer.start(inputSequence:)`, `transcriber.results` sowie `result.text` und `result.isFinal`, `AnalyzerInput(buffer:)`, `AssetInventory.assetInstallationRequest(supporting:)`, `finalizeAndFinishThroughEndOfInput()`.
- Das Long-Form-Modell von SpeechTranscriber nimmt kein eigenes Vokabular (Contextual Strings). Deshalb Whisper für das finale Transkript, nicht Apple.
- Der USB-Audio-Eingang erscheint nicht immer zuverlässig in Drittanbieter-Apps. Muss auf echtem Gerät verifiziert werden. Recording-Kategorie, kein VoIP-Modus.
- `.measurement` als Session-Modus nutzen, sonst verbiegt Apples Sprach-DSP den bandbegrenzten Funk.
- ATC-Funk ist verrauscht und bandbegrenzt, generische ASR macht Fehler. Ausbaupfad: ATC-Fine-Tune für Whisper (ATCO2/ATCOSIM).

## Aktueller Stand

- Phase 0 (Machbarkeit) als Swift-Skelett vorhanden: USB-Audio-Capture plus SpeechAnalyzer-Live-Transkript plus Eingang- und Pegelanzeige. Noch nicht auf echtem Gerät verifiziert.
- Rufzeichen-Filter, WhisperKit und Klassifikation noch nicht implementiert.

## Nächste Aufgabe

Erst wenn Phase 0 auf dem echten 15 Pro läuft (USB-Eingang wird erkannt, Transkript erscheint), Phase 1 darauf aufsetzen:

1. Rufzeichen-Konfiguration (Voll- und Kurzformen) plus fuzzy phonetischer Matcher mit Konversationsfenster (Modul C).
2. WhisperKit integrieren, getriggert nach Rufzeichen-Treffer (Modul B Schicht 2).
3. Foundation-Models-Klassifikation IFR/VFR (Modul D).
4. SwiftData-Persistenz plus IFR/VFR-gruppierte UI (Modul E).

## Konventionen

- Keine Gedankenstriche in Fließtext und Doku. Direkt und strukturiert schreiben.
- Doku, Kommentare und Commit-Messages auf Deutsch.
- Kein Netzwerkcode im Funk- und Verarbeitungspfad. Will eine Abhängigkeit online, ist das ein Fehler und muss gemeldet werden.
- Neue iOS-26-APIs vor Nutzung kurz gegen die SDK prüfen.

## Referenzdokumente

- `docs/Konzept.md`: vollständiges Produktkonzept.
- `docs/Umsetzungsplan.md`: technischer Plan mit API-Aufrufen und Datenmodell.
- `Phase0/README.md`: Setup und Erfolgskriterien der Test-App.

## Repo-Struktur (Zielbild)

```
.
├── CLAUDE.md
├── .gitignore
├── docs/
│   ├── Konzept.md              # aus ATC-Radio-to-Text-Konzept.md
│   └── Umsetzungsplan.md       # aus ATC-Radio-to-Text-Umsetzungsplan.md
└── ATCRadioText/               # Xcode-Projekt
    ├── ATCPhase0App.swift
    ├── LiveTranscriber.swift
    ├── ContentView.swift
    └── README.md
```
