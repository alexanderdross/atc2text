# ATC Radio-to-Text, Produktkonzept

## Zweck

iOS-App, die ATC-Sprechfunk in lesbaren Text umwandelt. Sie zeichnet nur auf,
wenn der Pilot selbst spricht oder ATC das eigene Rufzeichen nennt. So bleibt
das Ergebnis auf den fuer den Piloten relevanten Verkehr beschraenkt.

## Zwei Outputs

1. Audioaufnahmen im Sinne eines Voice Recorders.
2. Transkripte, nach IFR und VFR geclustert.

## Rahmenbedingungen

- Zielgeraet: iPhone 15 Pro oder Pro Max mit A17 Pro, iOS 26 oder neuer,
  Apple Intelligence vorausgesetzt.
- Vollstaendig on-device und offline. In der Luft gibt es keinen Mobilfunk.
  Kein Netzwerk im Funk- und Verarbeitungspfad, keine Cloud-Aufrufe.
- Sprachen Deutsch und Englisch. Ein Sprachwechsel innerhalb einer Uebermittlung
  ist moeglich und muss abgedeckt werden.
- Audio-Eingang ueber USB-C mit class-compliant Klinke zu USB-C Adapter. Nicht
  das eingebaute Mikrofon, da der Funk ueber die Bordanlage kommt.

## Warum on-device

Im Flug ist keine verlaessliche Netzverbindung vorhanden. Datenschutz und
Latenz sprechen ebenfalls fuer lokale Verarbeitung. Der A17 Pro und die neuen
iOS-26-Frameworks fuer Sprache und Foundation Models machen das moeglich.

## Nutzerfluss

1. Adapter anschliessen, Funkquelle verbinden.
2. App aufnehmen lassen. Sie hoert dauerhaft mit, speichert aber nur relevante
   Segmente.
3. Nach dem Flug stehen Audioaufnahmen und geclusterte Transkripte bereit.

## Relevanzfilter

Aufgezeichnet und transkribiert wird ein Segment, wenn eine der beiden
Bedingungen zutrifft:

- Der Pilot spricht selbst (Sendetaste oder erkannte eigene Stimme, je nach
  Ausbaustufe ueber den Signalweg).
- ATC nennt das eigene Rufzeichen, erkannt ueber den Rufzeichen-Matcher.

## Abgrenzung der Phasen

- Phase 0: Machbarkeit. USB-Audio-Eingang und Live-Transkript auf echter
  Hardware nachweisen.
- Phase 1: Rufzeichen-Filter, WhisperKit fuer das finale Transkript, IFR/VFR-
  Klassifikation, Persistenz und UI.

Der technische Plan mit API-Aufrufen und Datenmodell steht in
`docs/Umsetzungsplan.md`.
