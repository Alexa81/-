#!/bin/bash
# MOONAR RESYNTH automatic UI update, macOS LaunchAgent edition 1.1
# Installs Lua UI updates only. User presets, projects and JSFX are untouched.
set -euo pipefail
export PATH='/usr/bin:/bin:/usr/sbin:/sbin'
REAPER_DIR="${HOME}/Library/Application Support/REAPER"
SCRIPTS="${REAPER_DIR}/Scripts"
STATE="${REAPER_DIR}/MOONAR_RESYNTH"
LOG="${STATE}/autoupdate.log"
BASE='https://raw.githubusercontent.com/Alexa81/-/main/'
mkdir -p "$SCRIPTS" "$STATE/Backups"
log() { printf '%s  %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$LOG"; }
manifest=$(mktemp "${STATE}/.manifest.XXXXXXXX")
payload=$(mktemp "${SCRIPTS}/.MOONAR_RESYNTH_LIVE.XXXXXXXX")
trap 'rm -f "$manifest" "$payload"' EXIT
if ! /usr/bin/curl -fsSL --proto '=https' --connect-timeout 6 --max-time 18 \
    "${BASE}moonar/latest.txt" -o "$manifest" 2>/dev/null; then
  log 'No internet / cannot check GitHub; current installation unchanged'; exit 0
fi
extract() { /usr/bin/awk -F= -v key="$1" '$1 == key {print substr($0,length(key)+2); exit}' "$manifest" | /usr/bin/tr -d '\r'; }
latest=$(extract version)
release=$(extract controller)
expected=$(extract sha256)
if ! [[ "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
   [[ "$release" != "moonar/releases/v${latest}/MOONAR_RESYNTH_LIVE.lua" ]] || \
   ! [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]]; then
  log 'Invalid manifest; skipped update'; exit 0
fi
version_num() { local a b c; IFS=. read -r a b c <<< "$1"; echo $((10#$a*1000000+10#$b*1000+10#$c)); }
dest="${SCRIPTS}/MOONAR_RESYNTH_LIVE.lua"
current='0.0.0'
if [[ -f "$dest" ]]; then
  found=$(/usr/bin/head -c 600 "$dest" | /usr/bin/sed -nE 's/^[[:space:]]*-- MOONAR RESYNTH ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | /usr/bin/head -n1 || true)
  if [[ -n "$found" ]]; then current="$found"; fi
fi
if [[ "$(version_num "$current")" -ge "$(version_num "$latest")" ]]; then exit 0; fi
if ! /usr/bin/curl -fsSL --proto '=https' --connect-timeout 6 --max-time 28 \
    "${BASE}${release}" -o "$payload" 2>/dev/null; then
  log "Cannot download v${latest}; current installation unchanged"; exit 0
fi
actual=$(/usr/bin/shasum -a 256 "$payload" | /usr/bin/awk '{print tolower($1)}')
expected_lower=$(printf '%s' "$expected" | /usr/bin/tr 'A-F' 'a-f')
if [[ "$actual" != "$expected_lower" ]]; then
  log "SHA-256 mismatch for v${latest}; current installation unchanged"; exit 0
fi
if ! /usr/bin/grep -Fq -- "-- MOONAR RESYNTH ${latest} /" "$payload"; then
  log "Lua version marker mismatch for v${latest}"; exit 0
fi
if [[ -f "$dest" ]]; then
  backup="${STATE}/Backups/MOONAR_RESYNTH_LIVE_${current}_$(date +%Y%m%d_%H%M%S).lua"
  if ! /bin/cp -p "$dest" "$backup"; then log 'Backup failed; update cancelled'; exit 0; fi
fi
/bin/chmod 644 "$payload"
/bin/mv -f "$payload" "$dest"
log "Updated MOONAR Lua UI from v${current} to v${latest}; REAPER restart not required"
