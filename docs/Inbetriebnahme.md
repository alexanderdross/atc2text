# Phase 0 auf dem iPhone in Betrieb nehmen

Der Weg vom gepushten Branch zur laufenden Test-App auf dem iPhone 15 Pro.
Von oben nach unten abarbeiten.

- Repo: alexanderdross/atc2text
- Branch: claude/atc-radio-text-ios-f0u3xl
- Ziel: iPhone 15 Pro oder Pro Max, iOS 26

## Voraussetzungen

- Mac mit Xcode 26 oder neuer.
- iPhone 15 Pro oder Pro Max mit iOS 26.
- Apple Intelligence auf dem iPhone aktiviert.
- Class-compliant Klinke zu USB-C Adapter mit Funkquelle.
- Einmalig WLAN am Boden fuer das Sprachmodell.
- In Xcode mit einer Apple ID angemeldet, fuer die Signierung.

## Checkliste

### 1. Branch auf den Mac holen

Frisch klonen und auf den Arbeitsbranch wechseln. Der Branch ist noch nicht in
den Hauptzweig gemerged, du arbeitest direkt darauf.

```
git clone https://github.com/alexanderdross/atc2text.git
cd atc2text
git checkout claude/atc-radio-text-ios-f0u3xl
```

Ist das Repo schon lokal, stattdessen:

```
cd atc2text
git fetch origin
git checkout claude/atc-radio-text-ios-f0u3xl
git pull
```

### 2. Projekt in Xcode oeffnen

Das Projekt liegt im Wurzelverzeichnis.

```
open ATCRadioText.xcodeproj
```

### 3. Signierung einrichten

Target ATCRadioText waehlen, Reiter Signing and Capabilities. Team setzen und
Automatically manage signing anhaken. Meldet Xcode einen Konflikt bei der
Bundle-ID, gib ihr einen eindeutigen Wert, zum Beispiel com.deinname.atcphase0.

### 4. iPhone verbinden und als Ziel waehlen

iPhone 15 Pro per Kabel anschliessen, entsperren, am iPhone Diesem Computer
vertrauen bestaetigen. Oben in der Xcode-Toolbar das iPhone als Ausfuehrungsziel
waehlen. Der Simulator hat keinen USB-Audioeingang, es muss das echte Geraet sein.

### 5. Bauen und starten

Mit Cmd und R bauen und auf dem iPhone starten. Beim ersten Mal blockiert iOS
die Entwickler-App. Dann am iPhone unter Einstellungen, Allgemein, VPN und
Geraeteverwaltung den Entwickler freigeben und die App erneut starten.

### 6. Mikrofonzugriff erlauben

Beim ersten Tippen auf Aufnahme starten fragt die App den Mikrofonzugriff ab.
Erlauben. Der Text dazu steht in der Info.plist.

### 7. Sprachmodell bereitstellen

Ist das englische Sprachmodell noch nicht auf dem Geraet, laedt iOS es beim
ersten Start einmalig nach. Dafuer am Boden im WLAN sein. Der Status zeigt dann
lade Sprachmodell. Danach laeuft alles offline, im Flug wird nichts nachgeladen.

### 8. USB-Funkquelle anschliessen und testen

Adapter und Funkquelle anschliessen, Aufnahme starten und die Erfolgskriterien
pruefen.

## Erfolgskriterien

- Als Eingang erscheint der USB-Port, nicht das eingebaute Mikrofon.
- Der Pegelbalken schlaegt bei Funkverkehr aus.
- Im Blatt erscheint laufend Text, mit Zeitstempel pro Zeile.

## Wenn etwas klemmt

- Eingang zeigt das eingebaute Mikrofon: Der USB-Eingang erscheint nicht immer
  zuverlaessig in Drittanbieter-Apps. Adapter neu einstecken, App neu starten,
  notfalls anderen class-compliant Adapter testen. Bekannter Fallstrick, siehe
  CLAUDE.md.
- Untrusted Developer beim Start: Normal beim ersten Lauf mit freiem Zertifikat.
  Am iPhone unter Einstellungen, Allgemein, VPN und Geraeteverwaltung freigeben.
- Signing- oder Bundle-ID-Fehler: Team setzen und der Bundle-ID einen
  eindeutigen Wert geben. Automatic Signing an lassen.
- Build bricht ab: Die genaue Xcode-Meldung notieren. Der Build wurde nicht auf
  macOS verifiziert, die iOS-26-Aufrufe sind gegen die SDK geprueft. Bei einer
  Abweichung die Meldung zurueckmelden.

## Design ansehen

- Zahnrad oben rechts oeffnet die Einstellungen.
- CDU ist der Standard, Notizblock die hellere Alternative.
- CRT-Scanlines ein oder aus, wirkt nur im CDU-Stil.
- Beispieldaten anzeigen zeigt die spaetere Phase-1-Optik mit Sprecher-Kennung
  und Rufzeichen. Nur Vorschau, keine echte Transkription.

## Danach

Weiter mit Phase 1, erst wenn Phase 0 auf dem echten Geraet laeuft:

1. Rufzeichen-Konfiguration plus fuzzy phonetischer Matcher (Modul C).
2. WhisperKit fuer das finale Transkript (Modul B Schicht 2).
3. Foundation-Models-Klassifikation IFR gegen VFR (Modul D).
4. SwiftData-Persistenz plus gruppierte Ansicht (Modul E).
