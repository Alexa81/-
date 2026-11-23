#!/bin/bash
# MOONAR RESYNTH one-time repair for a stale in-plugin UPDATE button.
# Only updates Lua interface, JSFX 0.6.2, and MOONAR_UPDATE.lua.
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: This installer requires macOS." >&2; exit 1
fi
root="${MOONAR_REAPER_RESOURCE_PATH:-$HOME/Library/Application Support/REAPER}"
if [[ ! -f "$root/reaper.ini" ]]; then
  echo "ERROR: REAPER resource directory not found: $root" >&2
  echo "In REAPER: Options > Show REAPER resource path. This installer changed nothing." >&2
  exit 2
fi
mkdir -p "$root/Scripts" "$root/Effects" "$root/MOONAR_RESYNTH/Backups"
tmp="$(/usr/bin/mktemp -d "$root/MOONAR_RESYNTH/.repair.XXXXXXXX")"
trap '/bin/rm -rf "$tmp"' EXIT
base="https://raw.githubusercontent.com/Alexa81/-/main/"
get() { /usr/bin/curl -fsSL --proto '=https' --connect-timeout 10 --max-time 45 --retry 1 "$base$1" -o "$2"; }
field() { /usr/bin/awk -F= -v key="$1" '$1==key{print substr($0,length(key)+2); exit}' "$tmp/latest.txt" | /usr/bin/tr -d '\r'; }
verify() {
  local actual
  actual="$(/usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print tolower($1)}')"
  [[ "$actual" == "$2" ]] || { echo "ERROR: checksum mismatch: $1" >&2; exit 3; }
}
echo "MOONAR: resource path = $root"
get "moonar/latest.txt" "$tmp/latest.txt"
version="$(field version)"
controller="$(field controller)"
engine="$(field engine)"
controller_sha="$(field sha256)"
engine_sha="$(field engine_sha256)"
updater_sha="$(field updater_sha256)"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  [[ "$controller" != "moonar/releases/v${version}/MOONAR_RESYNTH_LIVE.lua" ]] ||
  [[ "$engine" != "moonar/releases/v${version}/MOONAR_Resynth_062.jsfx" ]] ||
  ! [[ "$controller_sha" =~ ^[0-9a-f]{64}$ ]] ||
  ! [[ "$engine_sha" =~ ^[0-9a-f]{64}$ ]] ||
  ! [[ "$updater_sha" =~ ^[0-9a-f]{64}$ ]]; then
  echo "ERROR: invalid update manifest. Nothing changed." >&2; exit 4
fi
echo "MOONAR: GitHub latest $version; verifying three components..."
get "$controller" "$tmp/MOONAR_RESYNTH_LIVE.lua"
get "$engine" "$tmp/MOONAR_Resynth_062.jsfx"
get "moonar/MOONAR_UPDATE.lua" "$tmp/MOONAR_UPDATE.lua"
verify "$tmp/MOONAR_RESYNTH_LIVE.lua" "$controller_sha"
verify "$tmp/MOONAR_Resynth_062.jsfx" "$engine_sha"
verify "$tmp/MOONAR_UPDATE.lua" "$updater_sha"
if ! /usr/bin/grep -Fq -- "-- MOONAR RESYNTH $version /" "$tmp/MOONAR_RESYNTH_LIVE.lua" ||
  ! /usr/bin/grep -Fq -- "MOONAR_BUILD=0.6.2" "$tmp/MOONAR_Resynth_062.jsfx" ||
  ! /usr/bin/grep -Fq -- "WHOLE PLUGIN REPAIR" "$tmp/MOONAR_UPDATE.lua"; then
  echo "ERROR: mismatched components. Nothing changed." >&2; exit 5
fi
stamp="$(date +%Y%m%d_%H%M%S)"
install() {
  local name="$1" target="$2" expected="$3" prior='' stage
  if [[ -f "$target" ]]; then
    prior="$(/usr/bin/shasum -a 256 "$target" | /usr/bin/awk '{print tolower($1)}')"
    if [[ "$prior" == "$expected" ]]; then
      echo "MOONAR: $name already verified"
      return
    fi
    /bin/cp -p "$target" "$root/MOONAR_RESYNTH/Backups/${name}_${stamp}.backup"
  fi
  stage="$target.moonar_stage_$$"
  /bin/cp "$tmp/$name" "$stage"
  /bin/chmod 644 "$stage"
  /bin/mv -f "$stage" "$target"
  echo "MOONAR: $name installed / repaired"
}
install MOONAR_UPDATE.lua "$root/Scripts/MOONAR_UPDATE.lua" "$updater_sha"
install MOONAR_Resynth_062.jsfx "$root/Effects/MOONAR_Resynth_062.jsfx" "$engine_sha"
install MOONAR_RESYNTH_LIVE.lua "$root/Scripts/MOONAR_RESYNTH_LIVE.lua" "$controller_sha"
echo "SUCCESS: MOONAR $version components installed/verified."
echo "Keep REAPER open. Reopen MOONAR_RESYNTH_LIVE in REAPER Actions on the selected track."
echo "From now on, UPDATE checks interface + JSFX and repairs damaged components."
echo "Presets and older JSFX were not removed."
