#!/bin/bash
# Feedback loop for Deezer's empty image (fork #15). Deezer marks "no image" with the MD5 of an
# empty string; a cover built from it is a blank image. The account's favourite tracks hold tracks
# with that marker on the track and its album (e.g. 3121382 "Coffee In The Pot"), and upstream
# lists favourites unfiltered.
#   1. wipes LMS's cache (cache.db, which holds the plugin's cached favourites and track metadata
#      with their covers already computed) and restarts LMS, so the code under test computes them
#   2. My collection -> Tracks: no item's icon may be the blank image
#   3. 3121382 queued by URL: its artwork in `status` may not be the blank image
# Prints counts and track names, never secrets. exit 1 = RED, exit 2 = inconclusive.
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08
EMPTY=d41d8cd98f00b204e9800998ecf8427e
TRACKS=3.2     # My collection -> Tracks in the plugin's menu
rpc() { "$D/rpc.sh" "$@"; }
red=0

# without the wipe, covers cached by an earlier run could give a false green
docker stop lms-deezer-dev >/dev/null && rm -f "$D"/config/cache/cache.db "$D"/config/cache/cache.db-* ||
  { echo "could not stop LMS and wipe its cache"; echo "VERDICT: inconclusive"; exit 2; }
"$D/restart.sh" || { echo "VERDICT: inconclusive"; exit 2; }

# with an empty cache, fetching the favourites can take longer than rpc.sh's timeout: warm up first
for _ in 1 2 3 4 5 6; do
  c=$(rpc $P '["deezer","items",0,1,"item_id:'$TRACKS'"]' | jq -r '.result.count // 0' 2>/dev/null)
  [[ "$c" =~ ^[1-9][0-9]*$ ]] && break; sleep 5
done
R=$(rpc $P '["deezer","items",0,2000,"item_id:'$TRACKS'"]')
n=$(jq -r '.result.loop_loop // [] | length' <<<"$R" 2>/dev/null)
audio=$(jq -r '[.result.loop_loop // [] | .[] | select(.isaudio == 1)] | length' <<<"$R" 2>/dev/null)
[[ "$audio" =~ ^[1-9][0-9]*$ ]] || { echo "My collection -> Tracks: no tracks (no answer or wrong menu id)"; echo "VERDICT: inconclusive"; exit 2; }
blank=$(jq -r --arg e "$EMPTY" '[.result.loop_loop[] | select((.image // "") | contains($e))] | length' <<<"$R")
noicon=$(jq -r '[.result.loop_loop[] | select((.image // "") == "")] | length' <<<"$R")
placeholder=$(jq -r '[.result.loop_loop[] | select((.image // "") | test("plugins/Deezer/html/"))] | length' <<<"$R")
echo "My collection -> Tracks: $audio tracks, blank image=$blank, placeholder=$placeholder, no icon=$noicon"
jq -r --arg e "$EMPTY" '.result.loop_loop[] | select((.image // "") | contains($e)) | "  blank: " + .name' <<<"$R" | head -20
[ "$blank" -ne 0 ] && red=1

rpc $P '["stop"]' >/dev/null; rpc $P '["playlist","clear"]' >/dev/null
rpc $P '["playlist","add","deezer://3121382.flac"]' >/dev/null; sleep 3
art=$(rpc $P '["status",0,1,"tags:K"]' | jq -r '.result.playlist_loop[0].artwork_url // ""')
case "$art" in
  "") echo "queued 3121382: no answer"; echo "VERDICT: inconclusive"; rpc $P '["playlist","clear"]' >/dev/null; exit 2 ;;
  *$EMPTY*) echo "queued 3121382: artwork is the blank image"; red=1 ;;
  *plugins/Deezer/html/*) echo "queued 3121382: artwork is the placeholder" ;;
  *) echo "queued 3121382: artwork $(grep -oE '[0-9a-f]{32}' <<<"$art" | head -1 | cut -c1-8)" ;;
esac
rpc $P '["playlist","clear"]' >/dev/null

[ $red = 1 ] && { echo "VERDICT: RED"; exit 1; }
echo "VERDICT: green"
