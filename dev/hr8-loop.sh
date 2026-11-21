#!/bin/bash
# Feedback loop for issue #8: play one Deezer URL on the headless test player and show
# what Deezer delivered (raw format) next to what LMS reports (bitrate, sample rate, bit depth).
# usage: hr8-loop.sh <label> <deezer-url> [seconds-to-wait]
# URLs: track deezer://<id>.flac | Flow deezer://user.flow | Mix deezer://artist/<id>/radio.dzr | Radio deezer://radio/<id>/tracks.dzr
# exit 1 (RED) if a FLAC track is reported below 300 kbps.
D=$(cd "$(dirname "$0")" && pwd)
LOG=$D/config/logs/server.log
P=02:00:00:00:00:08
LABEL=$1; URL=$2; WAIT=${3:-25}
rpc() { "$D/rpc.sh" "$@"; }

rpc "" '["debug","plugin.deezer","INFO"]' >/dev/null
rpc "" '["players",0,9]' | jq -e --arg p "$P" '.result.players_loop[]? | select(.playerid==$p)' >/dev/null \
  || { echo "player hr8-test not connected"; exit 2; }

OFF=$(wc -c <"$LOG")
rpc $P '["playlist","clear"]' >/dev/null
rpc $P '["playlist","play","'"$URL"'"]' >/dev/null

for _ in $(seq 1 "$WAIT"); do
  sleep 1
  S=$(rpc $P '["status","-",1,"tags:alroTIxdu"]')
  [ "$(jq -r '.result.mode' <<<"$S")" = play ] && [ "$(jq -r '.result.time // 0 | floor' <<<"$S")" -ge 3 ] && break
done
rpc $P '["stop"]' >/dev/null

echo "=== $LABEL  ($URL)"
jq -r '.result | "mode=\(.mode) time=\(.time // "-")",
  (.playlist_loop[0] // {} | "title=\(.title) | artist=\(.artist // "-")",
   "type=\(.type // "-") bitrate=\(.bitrate // "-") samplerate=\(.samplerate // "-") samplesize=\(.samplesize // "-") remote=\(.remote // "-")")' <<<"$S"
echo "--- server.log (plugin lines)"
tail -c +$((OFF + 1)) "$LOG" | grep -E "DEBUG-hr8|Deezer|deezer" | grep -vE "Getting https?://|Returning cached" \
  | sed -E -e 's/(arl|sid|token|license_token|api_token|hdnea)=[^&" ]+/\1=<REDACTED>/gi' -e 's/(for ARL) [0-9a-fA-F]+/\1 <REDACTED>/' | cut -c1-260

T=$(jq -r '.result.playlist_loop[0].type // ""' <<<"$S")
BR=$(jq -r '.result.playlist_loop[0].bitrate // ""' <<<"$S" | grep -oE '^[0-9]+')
if ! tail -c +$((OFF + 1)) "$LOG" | grep -q "DEBUG-hr8" || [ -z "$BR" ]; then
  echo "VERDICT: INCONCLUSIVE (no get_url result or no bitrate)"; exit 2
fi
if [[ "$T" =~ [Ff][Ll][Aa][Cc]|flc ]] && [ -n "$BR" ] && [ "$BR" -lt 300 ]; then
  echo "VERDICT: RED (FLAC reported at ${BR} kbps)"; exit 1
fi
echo "VERDICT: green (type=$T bitrate=${BR:-?})"
