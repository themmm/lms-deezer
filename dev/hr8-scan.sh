#!/bin/bash
# Probe which tracks Deezer offers as FLAC_24: play each id briefly, print FILESIZE_FLAC_24 and the delivered format.
# usage: hr8-scan.sh <id> [<id> ...]   (needs the [DEBUG-hr8] probes in the mounted plugin)
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08; LOG=$D/config/logs/server.log
for id in "$@"; do
  off=$(wc -c <"$LOG")
  "$D/rpc.sh" $P '["playlist","play","deezer://'"$id"'.flac"]' >/dev/null; sleep 4; "$D/rpc.sh" $P '["stop"]' >/dev/null
  new=$(tail -c +$((off + 1)) "$LOG")
  fs=$(grep -oE "FILESIZE_FLAC_24=[0-9]+" <<<"$new" | head -1)
  fmt=$(grep -oE "raw format=[A-Z0-9_]+" <<<"$new" | head -1)
  echo "$id ${fs:-FILESIZE_FLAC_24=?} ${fmt:-raw format=?}"
done
