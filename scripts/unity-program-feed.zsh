#!/bin/zsh
# Sets up the vMix program feed for Unity Intercom Server on mac4o-mini
# (docs/unity-intercom.md, "Program audio from a venue"). Run it with zsh, not
# bash, as the user that runs Unity Server, because it installs a LaunchAgent
# in that user's session. It asks for the vmix1 home read URL and keeps it in
# a 0600 file. Running it again rewrites run.sh and the agent, and keeps the URL.
set -eu

DIR="$HOME/Library/Application Support/unity-program-feed"
AGENT="$HOME/Library/LaunchAgents/ax.qo.unity-program-feed.plist"
LOG="$HOME/Library/Logs/unity-program-feed.log"

if ! command -v brew >/dev/null; then
  echo "Install Homebrew first: https://brew.sh" >&2
  exit 1
fi
# Homebrew's ffmpeg has no libsrt, so srt-live-transmit (from srt) receives
# the feed. BlackHole needs the admin password once, and CoreAudio loads it
# only after `sudo killall coreaudiod` or a reboot.
brew install ffmpeg srt blackhole-2ch

mkdir -p "$DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
chmod 700 "$DIR"

if [[ ! -s "$DIR/read-url" ]]; then
  print -n "Paste the vmix1 home read URL (srt://192.168.12.23:8890?...), then Enter: "
  read -rs url
  print
  [[ "$url" == srt://192.168.12.23:8890\?* ]] || { echo "That is not the home read URL." >&2; exit 1; }
  ( umask 077; print -r -- "$url" > "$DIR/read-url" )
fi

cat > "$DIR/run.sh" <<'EOF'
#!/bin/zsh
# Plays the relay's vmix1 audio, mono, into BlackHole 2ch, which Unity Server
# takes as its Input Device (input 1). launchd restarts it when it exits, for
# example while vMix is not publishing.
set -u
DIR="$HOME/Library/Application Support/unity-program-feed"
FFMPEG=$(command -v /opt/homebrew/bin/ffmpeg /usr/local/bin/ffmpeg | head -1)

# The audiotoolbox output takes a device index, and indexes change when
# devices come and go, so look BlackHole up by name on every start.
# audiotoolbox is an output only, so it lists devices while writing silence.
index=$("$FFMPEG" -hide_banner -f lavfi -i anullsrc -t 0.1 -f audiotoolbox -list_devices true - 2>&1 \
  | sed -nE 's/.*\[([0-9]+)\][[:space:]]+BlackHole 2ch,.*/\1/p' | head -1)
if [[ -z "$index" ]]; then
  echo "$(date '+%F %T') BlackHole 2ch not found" >&2
  exit 1
fi

# srt-live-transmit reads a latency= in the URL in ms, ffmpeg in µs. Keep -q:
# without it, srt-live-transmit prints the whole URL, passphrase included, at
# every start, and launchd writes that into the log. libsrt logs an empty
# ACKACK from the relay about once a second; it is harmless.
# ffmpeg's default probe buffers about 5 s of the live pipe, and audiotoolbox
# plays in real time, so that backlog would stay as delay: probe briefly.
SLT=$(command -v /opt/homebrew/bin/srt-live-transmit /usr/local/bin/srt-live-transmit | head -1)
"$SLT" -q -a:no -ll:error "$(<"$DIR/read-url")" file://con \
    2> >(grep --line-buffered -v 'UMSG: 6 INVALID SIZE' >&2) \
  | "$FFMPEG" -hide_banner -nostdin -loglevel warning \
      -probesize 32768 -analyzeduration 0 -fflags nobuffer -flags low_delay \
      -f mpegts -i pipe:0 -vn -ac 1 -ar 48000 \
      -f audiotoolbox -audio_device_index "$index" -
EOF
chmod 700 "$DIR/run.sh"

cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>ax.qo.unity-program-feed</string>
  <key>ProgramArguments</key>
  <array><string>/bin/zsh</string><string>$DIR/run.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/ax.qo.unity-program-feed" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT"
echo "Started. Log: $LOG"
echo "Status: launchctl print gui/$(id -u)/ax.qo.unity-program-feed | grep -E 'state|last exit'"
