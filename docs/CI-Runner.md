# Self-hosted CI-Runner einrichten

Die CI laeuft ausschliesslich auf self-hosted Runnern. Zwei Stueck:

- Linux-Runner (Root-Server): fuer die Jobs Guardrails und Auto-Merge.
- macOS-Runner (Mac mit Xcode 26): fuer den iOS-Build. Ein iOS-Build braucht
  zwingend macOS.

GitHub vergibt an self-hosted Runner automatisch die Labels `self-hosted`, das
Betriebssystem (`Linux` oder `macOS`) und die Architektur. Die Workflows nutzen
`[self-hosted, Linux]` und `[self-hosted, macOS]`, die passen also ohne eigene
Labels.

Das Registrierungs-Token zeigt GitHub im UI an. Es ist kurzlebig und gehoert
nicht in eine Datei. Unten steht dafuer der Platzhalter TOKEN.

## 1. Linux-Runner auf dem Root-Server

1. Auf GitHub: Repo `atc2text` → Settings → Actions → Runners → New self-hosted
   runner → Linux, passende Architektur.
2. Auf dem Server, mit einem eigenen Nutzer, nicht als root:

```
mkdir actions-runner && cd actions-runner
# Download-Befehl aus dem GitHub-UI hier einsetzen
./config.sh --url https://github.com/alexanderdross/atc2text --token TOKEN --name root-linux
sudo ./svc.sh install
sudo ./svc.sh start
```

3. Voraussetzungen: git und bash. Node bringt die Runner-Software mit.
4. Der Dienst startet nach einem Reboot automatisch neu.

## 2. macOS-Runner auf dem Mac

1. Auf GitHub: Repo `atc2text` → Settings → Actions → Runners → New self-hosted
   runner → macOS.
2. Voraussetzung: Xcode 26 ist installiert. Kurz pruefen:

```
xcodebuild -version
```

3. Auf dem Mac einrichten:

```
mkdir actions-runner && cd actions-runner
# Download-Befehl aus dem GitHub-UI hier einsetzen
./config.sh --url https://github.com/alexanderdross/atc2text --token TOKEN --name mac-xcode26
./svc.sh install
./svc.sh start
```

4. Die Runner-Software muss aktuell sein, da `actions/checkout` ab v5 Node 24
   voraussetzt. Standardmaessig aktualisiert sich der Runner selbst.

## 3. Label automerge anlegen

Damit die Auto-Merge-Automatik greift, muss das Label existieren und am PR
gesetzt sein.

1. Repo `atc2text` → Issues → Labels → New label.
2. Name: `automerge`. Farbe und Beschreibung frei.

## 4. Pruefen, ob alles laeuft

1. Einen Commit auf den Branch pushen.
2. Im Actions-Tab: Guardrails laeuft auf dem Linux-Runner, iOS-Build auf dem
   Mac. Beide sollten von `queued` auf `in progress` und dann auf gruen wechseln.
3. Bei einem PR mit dem Label `automerge` wird nach gruenem CI automatisch per
   Squash gemergt.

## Betrieb und Sicherheit

- Runner nicht als root betreiben, eigener Nutzer.
- Beide laufen als Dienst und ueberstehen einen Reboot.
- Das Repo ist privat, nur Berechtigte koennen Workflows ausloesen. Wird das
  Repo je oeffentlich, self-hosted Runner nur mit Einschraenkungen betreiben,
  da PRs von Fremden sonst Code auf den Runnern ausfuehren koennen.
