#!/bin/bash
# Feedback loop for fork #14: adding a playlist URL must queue only Deezer tracks.
# Adds "Love Machine" by URL, then checks:
#   1. every queue entry is a Deezer track (deezer://<id>.<ext>), not a link or text item such as
#      the playlist's sort-order toggle
#   2. `status` over the whole queue answers with one entry per queued item; a broken entry makes
#      it fail with "Can't call method "can" on unblessed reference", which also loses cover and title
#   3. that error does not appear in server.log during the run
# exit 1 = RED.
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08; LOG=$D/config/logs/server.log
PL=deezer://playlist:13715702701
rpc() { "$D/rpc.sh" "$@"; }
red=0
OFF=$(wc -c <"$LOG")

rpc $P '["stop"]' >/dev/null; rpc $P '["playlist","clear"]' >/dev/null
rpc $P '["playlist","add","'$PL'"]' >/dev/null; sleep 5
n=$(rpc $P '["playlist","tracks","?"]' | jq -r '.result._tracks // 0')
echo "queue entries: $n"
[ "$n" -eq 0 ] && { echo "queue is empty, nothing to check"; echo "VERDICT: inconclusive"; exit 2; }

tracks=0; other=""
for ((i = 0; i < n; i++)); do
  p=$(rpc $P '["playlist","path",'$i',"?"]' | jq -r '.result._path // ""')
  if [[ "$p" =~ ^deezer://[0-9]+\.[a-z0-9]+$ ]]; then tracks=$((tracks + 1)); else other+="  [$i] ${p:-<no path>}"$'\n'; fi
done
echo "Deezer tracks in queue: $tracks"
if [ -n "$other" ]; then echo "other entries:"; printf '%s' "$other"; red=1; else echo "other entries: none"; fi

S=$(rpc $P '["status",0,'$n',"tags:acdlK"]')
got=$(jq -r '.result.playlist_loop // [] | length' <<<"$S" 2>/dev/null)
untitled=$(jq -r '[.result.playlist_loop // [] | .[] | select((.title // "") == "")] | length' <<<"$S" 2>/dev/null)
echo "status over the queue: ${got:-no answer} of $n entries, ${untitled:-?} without title"
[ "${got:-0}" -ne "$n" ] && red=1
[ "${untitled:-1}" -ne 0 ] && red=1

errs=$(tail -c +$((OFF + 1)) "$LOG" | grep -c "Can't call method \"can\" on unblessed reference")
echo "'unblessed reference' errors in server.log: $errs"
[ "$errs" -ne 0 ] && red=1

rpc $P '["playlist","clear"]' >/dev/null
[ $red = 1 ] && { echo "VERDICT: RED"; exit 1; }
echo "VERDICT: green"
