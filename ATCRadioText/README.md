# ATCRadioText, Phase 0

Machbarkeits-Test-App. Prueft zwei Dinge auf echter Hardware:

1. Der USB-Audio-Eingang (Klinke zu USB-C Adapter) wird als bevorzugter Eingang erkannt.
2. Aus diesem Eingang entsteht ein Live-Transkript ueber Apples SpeechAnalyzer (neu in iOS 26).

Rufzeichen-Filter, WhisperKit und die IFR/VFR-Klassifikation sind nicht Teil von Phase 0.

## Voraussetzungen

- Xcode 26 oder neuer.
- iPhone 15 Pro oder Pro Max mit iOS 26 und aktivierter Apple Intelligence.
- Class-compliant USB-C-Audioadapter mit angeschlossener Funkquelle.
- Signierung: in Xcode unter Signing and Capabilities ein eigenes Development Team eintragen. Das Projekt ist auf Automatic Signing gestellt und enthaelt bewusst kein Team.

## Aufbau

```
ATCRadioText/
  ATCPhase0App.swift     App-Einstieg, reine SwiftUI-App
  LiveTranscriber.swift  Audio-Capture plus SpeechAnalyzer-Transkription
  ContentView.swift      Oberflaeche: Eingang, Pegel, Scratchpad-Textausgabe
  ScratchpadDesign.swift Farb- und Schriftpalette der beiden Stile
  Info.plist             enthaelt NSMicrophoneUsageDescription
```

## Textausgabe im Scratchpad-Stil

Die Textausgabe ist als Piloten-Scratchpad gestaltet. Zwei Stile:

- CDU: avionischer Look, Monospace, gruen auf schwarz. Standard.
- Notizblock: hellere Schreibblock-Optik mit roter Randlinie.

Umgeschaltet wird in den Einstellungen (Zahnrad oben rechts). Die Auswahl
bleibt ueber AppStorage erhalten. Sprecher-Kennung (ATC gegen eigene Sendung)
und Rufzeichen-Hervorhebung sind im Zeilenmodell bereits vorgesehen, werden
aber erst in Phase 1 mit Daten gefuellt.

Weitere Schalter in den Einstellungen:

- CRT-Scanlines: dezentes Zeilenraster, wirkt nur im CDU-Stil.
- Beispieldaten anzeigen: blendet eine Beispiel-Mitschrift mit Sprecher-Kennung
  und hervorgehobenem Rufzeichen ein. Nur zur Ansicht der Phase-1-Darstellung,
  keine echte Transkription.

Das Xcode-Projekt liegt in `ATCRadioText.xcodeproj` im Wurzelverzeichnis.

## Starten

1. `ATCRadioText.xcodeproj` in Xcode 26 oeffnen.
2. Development Team setzen.
3. Auf dem iPhone 15 Pro bauen und starten.
4. USB-Adapter mit Funkquelle anschliessen.
5. In der App auf Aufnahme starten tippen und den Mikrofonzugriff erlauben.

## Erfolgskriterien

- Als Eingang erscheint der USB-Port, nicht das eingebaute Mikrofon.
- Der Pegelbalken schlaegt bei Funkverkehr aus.
- Im Transkriptbereich erscheint laufend Text.

Wird statt USB das eingebaute Mikrofon angezeigt, greift die USB-Erkennung
in Drittanbieter-Apps nicht zuverlaessig. Dann Route und Adapter pruefen.
Das ist ein bekannter Fallstrick, siehe CLAUDE.md.

## Netzwerk

Der Verarbeitungspfad ist vollstaendig on-device. Einzige moegliche Ausnahme
ist die einmalige Bereitstellung des Apple-Sprachmodells ueber `AssetInventory`.
Ist das Modell fuer die Locale noch nicht installiert, laedt das System es
einmalig nach. Das laeuft am Boden vor dem Einsatz, nicht waehrend der
Verarbeitung. Zur Laufzeit im Funkbetrieb erfolgt kein Netzwerkzugriff.

## Korrigierte iOS-26-API-Aufrufe

Die Signaturen des SpeechAnalyzer-Skeletts wurden gegen die Framework-Interfaces
geprueft und angepasst. Wesentliche Korrekturen:

- `SpeechAnalyzer(modules:)` gibt es nicht. Der Initialisierer verlangt das
  Argument `options`, hier `SpeechAnalyzer(modules: [transcriber], options: nil)`.
- `SpeechTranscriber(locale:)` gibt es nicht. Genutzt wird
  `init(locale:transcriptionOptions:reportingOptions:attributeOptions:)`.
- `AnalyzerInput(buffer:)` ist korrekt und wird mit einem `AVAudioPCMBuffer` genutzt.
- `transcriber.results` ist eine `AsyncSequence`. Das Ergebnis hat `text` als
  `AttributedString` und `isFinal` als `Bool`. Fuer die Anzeige wird
  `String(ergebnis.text.characters)` verwendet.
- `AssetInventory.assetInstallationRequest(supporting:)` liefert ein optionales
  `AssetInstallationRequest`. Der Download startet ueber `downloadAndInstall()`.
- `finalizeAndFinishThroughEndOfInput()` ist korrekt und beendet den Analyzer.
- Vor dem Start wird das Audioformat ueber
  `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)` ermittelt und der
  Tap-Puffer bei Bedarf mit `AVAudioConverter` gewandelt.

Details zur Herleitung stehen in `docs/Umsetzungsplan.md`.
