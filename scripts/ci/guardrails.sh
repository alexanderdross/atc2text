#!/usr/bin/env bash
set -euo pipefail

# Deterministische Qualitaets- und Konventionspruefungen fuer ATC Radio-to-Text.
# Prueft die harten Rahmenbedingungen und Konventionen aus CLAUDE.md. Laeuft ohne
# Xcode, daher auf jedem Linux-Runner und lokal. Rueckgabe ungleich 0 bei Verstoss.

fehler=0
melde() { printf 'FEHLER: %s\n' "$*" >&2; fehler=1; }
ok() { printf 'ok: %s\n' "$*"; }

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

# 1. Keine Gedankenstriche (Em-Dash oder En-Dash) in Doku und Swift.
#    Bytefolgen statt \x-Klassen, damit BSD- und GNU-grep gleich reagieren.
#    Box-Zeichen der Repo-Struktur (anderes Byte) werden bewusst nicht getroffen.
if LC_ALL=C grep -rn --include='*.md' --include='*.swift' \
     -e $'\xe2\x80\x93' -e $'\xe2\x80\x94' .; then
  melde "Gedankenstrich gefunden. Durch Komma, Punkt oder Umformulierung ersetzen."
else
  ok "keine Gedankenstriche in Doku und Swift"
fi

# 2. Kein Netzwerkcode im Verarbeitungspfad (Swift der App).
#    Die einmalige Modellbereitstellung ueber AssetInventory ist Apples System-API
#    und wird von diesem Muster bewusst nicht getroffen.
netz_muster='URLSession|URLRequest|URLConnection|NWConnection|NWListener|NWPathMonitor|CFStream|CFSocket|\.dataTask|\.downloadTask|\.uploadTask|Socket\('
if grep -rnE --include='*.swift' "$netz_muster" ATCRadioText; then
  melde "Moeglicher Netzwerkcode im Verarbeitungspfad. Kein Netzwerk im Funk- und Verarbeitungspfad erlaubt."
else
  ok "kein Netzwerkcode im Verarbeitungspfad"
fi

# 3. AVAudioSession-Modus .measurement ist Pflicht.
if grep -rnE --include='*.swift' 'mode:[[:space:]]*\.measurement' ATCRadioText >/dev/null; then
  ok "AVAudioSession-Modus .measurement gesetzt"
else
  melde "AVAudioSession-Modus .measurement nicht gefunden. Pflicht laut Rahmenbedingungen."
fi

# 4. NSMicrophoneUsageDescription muss in der Info.plist stehen.
if grep -q 'NSMicrophoneUsageDescription' ATCRadioText/Info.plist; then
  ok "NSMicrophoneUsageDescription vorhanden"
else
  melde "NSMicrophoneUsageDescription fehlt in ATCRadioText/Info.plist."
fi

if [ "$fehler" -ne 0 ]; then
  printf '\nGuardrails fehlgeschlagen.\n' >&2
  exit 1
fi
printf '\nGuardrails ok.\n'
