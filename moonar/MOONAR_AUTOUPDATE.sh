#!/bin/bash
# MOONAR RESYNTH AUTOUPDATE v1.2 - for macOS, no REAPER restart
# Updates only Scripts/MOONAR_RESYNTH_LIVE.lua. Does not change user presets or JSFX.
set -euo pipefail
export PATH='/usr/bin:/bin:/usr/sbin:/sbin'
REAPER_DIR="${MOONAR_REAPER_RESOURCE_PATH:-${HOME}/Library/Application Support/REAPER}"
SCRIPTS="${REAPER_DIR}/Scripts"
STATE="${REAPER_DIR}/MOONAR_RESYNTH"
LOG="${STATE}/autoupdate.log"
BASE='https://raw.githubusercontent.com/Alexa81/-/main/'
mkdir -p "$SCRIPTS" "$STATE/Backups"
log() { printf '%s  %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" | /usr/bin/tee -a "$LOG"; }
fail() { log "ERROR: $*"; exit 1; }
manifest=$(/usr/bin/mktemp "${STATE}/.manifest.XXXXXXXX") || fail 'Cannot create manifest temp file'
payload=$(/usr/bin/mktemp "${SCRIPTS}/.MOONAR_RESYNTH_LIVE.XXXXXXXX") || fail 'Cannot create Lua temp file'
trap 'rm -f "$manifest" "$payload"' EXIT
if ! /usr/bin/curl -fsSL --proto '=https' --connect-timeout 8 --max-time 30 \
  "${BASE}moonar/latest.txt" -o "$manifest"; then
  fail 'GitHub manifest download failed. Existing MOONAR files are unchanged.'
fi
extract() { /usr/bin/awk -F= -v key="$1" '$1 == key {print substr($0,length(key)+2); exit}' "$manifest" | /usr/bin/tr -d '\r'; }
latest=$(extract version)
release=$(extract controller)
expected=$(extract sha256)
if ! [[ "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
   [[ "$release" != "moonar/releases/v${latest}/MOONAR_RESYNTH_LIVE.lua" ]] || \
   ! [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]]; then
  fail 'Manifest is malformed. Existing MOONAR files are unchanged.'
fi
version_num() {
  local a b c
  IFS=. read -r a b c <<< "$1"
  echo $((10#$a*1000000+10#$b*1000+10#$c))
}
dest="${SCRIPTS}/MOONAR_RESYNTH_LIVE.lua"
current='0.0.0'
local_sha=''
if [[ -f "$dest" ]]; then
  found=$(/usr/bin/head -c 700 "$dest" | /usr/bin/sed -nE 's/^[[:space:]]*-- MOONAR RESYNTH ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | /usr/bin/head -n1 || true)
  if [[ -n "$found" ]]; then current="$found"; fi
  local_sha=$(/usr/bin/shasum -a 256 "$dest" | /usr/bin/awk '{print tolower($1)}')
fi
expected_lower=$(printf '%s' "$expected" | /usr/bin/tr 'A-F' 'a-f')
if [[ "$(version_num "$current")" -gt "$(version_num "$latest")" ]]; then
  log "Skipped: local v${current} newer than published v${latest}."
  exit 0
fi
if [[ "$(version_num "$current")" -eq "$(version_num "$latest")" && "$local_sha" == "$expected_lower" ]]; then
  log "Already current: MOONAR RESYNTH v${latest} (SHA-256 verified)."
  exit 0
fi
log "Installing MOONAR v${latest} (local: v${current})..."
if ! /usr/bin/curl -fsSL --proto '=https' --connect-timeout 8 --max-time 40 \
  "${BASE}${release}" -o "$payload"; then
  fail "Could not download MOONAR v${latest}. Existing files unchanged."
fi
actual=$(/usr/bin/shasum -a 256 "$payload" | /usr/bin/awk '{print tolower($1)}')
if [[ "$actual" != "$expected_lower" ]]; then
  fail "SHA-256 mismatch for MOONAR v${latest}. Existing files unchanged."
fi
if ! /usr/bin/grep -Fq -- "-- MOONAR RESYNTH ${latest} /" "$payload"; then
  fail "Release version header mismatch. Existing files unchanged."
fi
if [[ -f "$dest" ]]; then
  backup="${STATE}/Backups/MOONAR_RESYNTH_LIVE_${current}_$(date +%Y%m%d_%H%M%S).lua"
  /bin/cp -p "$dest" "$backup" || fail 'Backup failed; existing files unchanged.'
  log "Backup saved: $backup"
fi
/bin/chmod 644 "$payload"
/bin/mv -f "$payload" "$dest" || fail 'Cannot replace Lua controller.'
log "SUCCESS: MOONAR RESYNTH v${latest} installed at: $dest"
log 'REAPER can stay open. Its running Lua GUI may reload automatically if it is already registered.'
