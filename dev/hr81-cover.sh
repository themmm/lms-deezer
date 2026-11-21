#!/bin/bash
# Feedback loop for covers of tracks that only play via FALLBACK ("Love Machine").
#   145534376 "Waiting For A Train", 145534390 "Midnight Man": md5_image is the MD5 of "" (no image)
#   916462 "Fool's Overture", 58082321 "Svalutation": md5_image points to a removed image (CDN 302 -> empty image)
# For each: cover in the queue before playing (same data as the playlist view), while playing, and in the
# queue after playing (after the metadata refresh); each cover id is checked on the CDN (200 = image, 302 = gone).
# exit 1 = RED.
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08
EMPTY=d41d8cd98f00b204e9800998ecf8427e
rpc() { "$D/rpc.sh" "$@"; }
art() { jq -r '.result.playlist_loop[0].artwork_url // "-"' | grep -oE 'cover%2F[0-9a-f]{32}' | sed 's/cover%2F//' | head -1; }
cdn() { [ -z "$1" ] && { echo none; return; }; [ "$1" = $EMPTY ] && { echo empty; return; }
  c=$(curl -s -o /dev/null -w '%{http_code}' "https://e-cdns-images.dzcdn.net/images/cover/$1/500x500-000000-80-0-0.jpg"); [ "$c" = 200 ] && echo ok || echo "gone($c)"; }
red=0
rpc $P '["stop"]' >/dev/null; rpc $P '["playlist","clear"]' >/dev/null
rpc $P '["playlist","add","deezer://playlist:13715702701"]' >/dev/null; sleep 5
n=$(rpc $P '["playlist","tracks","?"]' | jq -r '.result._tracks')
# code without upstream PR #95 queues the playlist's sort link at index 0, and status fails while it
# is the current entry; drop such entries so this loop measures covers only
for ((i = n - 1; i >= 0; i--)); do
  [[ "$(rpc $P '["playlist","path",'$i',"?"]' | jq -r '.result._path // ""')" == deezer://* ]] || rpc $P '["playlist","delete",'$i']' >/dev/null
done
n=$(rpc $P '["playlist","tracks","?"]' | jq -r '.result._tracks')
for id in 145534376 145534390 916462 58082321; do
  idx=-1; for ((i = 0; i < n; i++)); do [[ "$(rpc $P '["playlist","path",'$i',"?"]' | jq -r .result._path)" == "deezer://$id."* ]] && idx=$i && break; done
  [ $idx -lt 0 ] && { echo "$id not in queue"; red=1; continue; }
  b=$(rpc $P '["status",'$idx',1,"tags:K"]' | art)
  rpc $P '["playlist","index",'$idx']' >/dev/null; sleep 7
  p=$(rpc $P '["status","-",1,"tags:K"]' | art); rpc $P '["stop"]' >/dev/null; sleep 1
  a=$(rpc $P '["status",'$idx',1,"tags:K"]' | art)
  line="$id"; for c in "$b" "$p" "$a"; do s=$(cdn "$c"); line+="  ${c:0:8}=$s"; [ "$s" != ok ] && red=1; done
  echo "$line   (before / playing / after)"
done
[ $red = 1 ] && { echo "VERDICT: RED"; exit 1; }
echo "VERDICT: green"
