#!/bin/bash
# Feedback loop for "unplayable track stops playback" (fallback resolution, upstream PR #81).
# Plays <url> starting at playlist index <start> and records a timeline of the player state,
# then prints the plugin/streaming log lines written meanwhile (secrets redacted by the plugin).
# usage: hr81-loop.sh <deezer-url> [start-index] [seconds] [end]
#   end: once playing, seek to 8 s before the end of the start track to test the transition to the next one
# exit 1 (RED) if the player ends up stopped while tracks after <start> remain in the queue.
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08; LOG=$D/config/logs/server.log
URL=$1; START=${2:-0}; SECS=${3:-30}; SEEK=${4:-}
rpc() { "$D/rpc.sh" "$@"; }

rpc $P '["stop"]' >/dev/null; rpc $P '["playlist","clear"]' >/dev/null
OFF=$(wc -c <"$LOG")
if [ "$START" -gt 0 ]; then
  rpc $P '["playlist","add","'"$URL"'"]' >/dev/null; sleep 3
  rpc $P '["playlist","index","'"$START"'"]' >/dev/null
else
  rpc $P '["playlist","play","'"$URL"'"]' >/dev/null
fi

if [ "$SEEK" = end ]; then
  for _ in $(seq 1 15); do sleep 1; S=$(rpc $P '["status","-",1,"tags:d"]'); dur=$(jq -r '.result.duration // 0 | floor' <<<"$S"); [ "$(jq -r .result.mode <<<"$S")" = play ] && [ "$dur" -gt 20 ] && break; done
  rpc $P '["time",'"$((dur - 8))"']' >/dev/null; echo "seek to $((dur - 8))s of ${dur}s"
fi
last=""
for s in $(seq 1 "$SECS"); do
  sleep 1
  S=$(rpc $P '["status","-",1,"tags:aIl"]')
  line=$(jq -r '.result | "mode=\(.mode) idx=\(.playlist_cur_index // "-")/\(.playlist_tracks // 0) \(.playlist_loop[0].artist // "-") - \(.playlist_loop[0].title // "-")"' <<<"$S")
  [ "$line" != "$last" ] && echo "t+${s}s $line"; last=$line
done
rpc $P '["stop"]' >/dev/null

echo "--- log"
tail -c +$((OFF + 1)) "$LOG" | grep -E "Plugins::Deezer|StreamingController|Song::(open|getNextSong)|rror|failed|Failed" \
  | grep -vE "Using cache key|Returning cached|context will expire|_get \(|computing hashkey|^[[:space:]]" \
  | sed -E 's/(hdnea=)[^ ]*/\1<REDACTED>/; s/[0-9a-fA-F]{192,}/<REDACTED>/g; s/(api_token=)[^& ]*/\1<REDACTED>/; s/^\[[0-9-]+ ([0-9:.]+)\]/\1/' | cut -c1-220

mode=$(jq -r '.result.mode' <<<"$S"); idx=$(jq -r '.result.playlist_cur_index // 0' <<<"$S"); n=$(jq -r '.result.playlist_tracks // 0' <<<"$S")
if grep -q "mode=stop" <<<"$last" && [ "$idx" -lt $((n - 1)) ]; then echo "VERDICT: RED (stopped at idx $idx of $n)"; exit 1; fi
echo "VERDICT: green (last: $last)"
