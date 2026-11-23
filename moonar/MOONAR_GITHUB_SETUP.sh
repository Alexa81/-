#!/bin/bash
# One-time setup of automatic MOONAR RESYNTH Lua UI updates on macOS.
set -euo pipefail
export PATH='/usr/bin:/bin:/usr/sbin:/sbin'
if [[ "$(uname -s)" != 'Darwin' ]]; then echo 'This setup is for macOS.'; exit 1; fi
REAPER_DIR="${HOME}/Library/Application Support/REAPER"
SCRIPTS="${REAPER_DIR}/Scripts"
STATE="${REAPER_DIR}/MOONAR_RESYNTH"
AGENTS="${HOME}/Library/LaunchAgents"
LABEL='com.moonar.resynth.autoupdate'
BASE='https://raw.githubusercontent.com/Alexa81/-/main/moonar/'
mkdir -p "$SCRIPTS" "$STATE" "$AGENTS"
echo 'Installing MOONAR automatic updates...'
for item in MOONAR_AUTOUPDATE.sh MOONAR_UPDATE.lua; do
  if [[ "$item" == *.sh ]]; then target="${STATE}/${item}"; else target="${SCRIPTS}/${item}"; fi
  tmp="${target}.download.$$"
  trap 'rm -f "$tmp"' EXIT
  /usr/bin/curl -fsSL --proto '=https' --connect-timeout 8 --max-time 30 "${BASE}${item}" -o "$tmp"
  /bin/mv -f "$tmp" "$target"
  /bin/chmod 700 "$target"
done
plist="${AGENTS}/${LABEL}.plist"
cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string>
    <string>${STATE}/MOONAR_AUTOUPDATE.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>900</integer>
  <key>StandardOutPath</key><string>${STATE}/autoupdate.stdout.log</string>
  <key>StandardErrorPath</key><string>${STATE}/autoupdate.stderr.log</string>
</dict></plist>
EOF
user_domain="gui/$(/usr/bin/id -u)"
/bin/launchctl bootout "$user_domain/$LABEL" 2>/dev/null || true
/bin/launchctl bootstrap "$user_domain" "$plist"
echo 'MOONAR auto updates enabled. GitHub checked about every 15 minutes.'
echo 'REAPER can stay open. Open existing MOONAR_RESYNTH_LIVE action in REAPER.'
echo 'No JSFX audio engines or user presets were replaced.'
