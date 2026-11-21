#!/bin/bash
# Feedback loop for album track filtering (PR #82 rework): load two albums into the queue and
# count the Deezer tracks in it.
#   108288 Boney M. "Rivers Of Babylon": all 14 readable:false, all 14 playable  -> expect 14
#   248956 Phil Carmen "Walkin' The Dog": all 9 readable:true, none playable      -> expect 0
# Also reports queue entries that are not Deezer tracks (e.g. message or link items). exit 1 = RED.
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08
rpc() { "$D/rpc.sh" "$@"; }
red=0
for spec in 108288:14 248956:0; do
  a=${spec%%:*}; want=${spec##*:}
  rpc $P '["stop"]' >/dev/null; rpc $P '["playlist","clear"]' >/dev/null
  rpc $P '["playlist","add","deezer://album:'$a'"]' >/dev/null; sleep 5
  n=$(rpc $P '["playlist","tracks","?"]' | jq -r '.result._tracks // 0')
  tracks=0; other=0
  for ((i = 0; i < n; i++)); do
    p=$(rpc $P '["playlist","path",'$i',"?"]' | jq -r '.result._path // ""')
    if [[ "$p" =~ ^deezer://[0-9]+\.[a-z0-9]+$ ]]; then tracks=$((tracks + 1)); else other=$((other + 1)); fi
  done
  v=ok; [ "$tracks" -ne "$want" ] && v=WRONG && red=1
  printf 'album %-7s tracks in queue=%-3s expected=%-3s other entries=%s  %s\n' "$a" "$tracks" "$want" "$other" "$v"
done
rpc $P '["playlist","clear"]' >/dev/null
[ $red = 1 ] && { echo "VERDICT: RED"; exit 1; }
echo "VERDICT: green"
