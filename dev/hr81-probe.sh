#!/bin/bash
# Play each Deezer track id on its own for a few seconds and report whether it plays,
# which id getTrackUrl resolved it to (fallback) and whether no stream was found ("can't get tracks").
# usage: hr81-probe.sh <id> [<id> ...]
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08; LOG=$D/config/logs/server.log
for id in "$@"; do
  off=$(wc -c <"$LOG")
  "$D/rpc.sh" $P '["playlist","play","deezer://'"$id"'.flc"]' >/dev/null; sleep 4
  m=$("$D/rpc.sh" $P '["mode","?"]' | jq -r .result._mode); "$D/rpc.sh" $P '["stop"]' >/dev/null
  new=$(tail -c +$((off + 1)) "$LOG")
  fb=$(grep -oE "after fallback resolution: [0-9]+" <<<"$new" | head -1 | awk '{print $4}')
  nr=$(grep -q "can't get tracks" <<<"$new" && echo "NO-STREAM")
  got=$(grep -q "got [a-z]*@" <<<"$new" && echo streams)
  printf '%-11s mode=%-5s resolved=%-11s %s %s\n' "$id" "$m" "${fb:-?}" "${got:--}" "$nr"
done
