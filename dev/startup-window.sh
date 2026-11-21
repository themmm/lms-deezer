#!/bin/bash
# Feedback loop for the startup window (fork #21). Right after an LMS start the account has no ARL
# in its context until refreshArl has finished (about 1 s after the web server is up). A list
# built in that window must still be filtered by rights and Fallback, not by readable.
# Each run restarts LMS, then as soon as the test player is back opens playlist "Love Machine"
# twice at once: in the menu (deezer items) and by queueing its URL. Each result is classified:
#   playable  the 12 Fallback-only tracks are in, the 2 tracks without rights and Fallback are out
#   readable  the fallback to the readable flag: Fallback-only tracks missing, 2540822 listed
# A request counts as inside the window when the plugin asked for the playlist's tracks before
# "Refreshed Arl" in server.log. After the window both are opened again, to see whether a
# readable result outlives it (cache). Prints only ids, counts and timestamps, never log lines.
# usage: ./startup-window.sh [runs]   (default 5). exit 1 = RED, 2 = no request hit the window
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08; LOG=$D/config/logs/server.log
PL_ID=13715702701; PL_NAME="Love Machine"
UNPLAYABLE="2540822 3083376"
VIA_FALLBACK="2884478 5425390 145534376 471798752 70221941 2270632 26169641 145534390 916462 58082321 6776198 5425389"
RUNS=${1:-5}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
rpc() { "$D/rpc.sh" "$@"; }

# the playlist's position in My collection -> Playlists (item 3.0), looked up before the restarts
idx=$(rpc $P '["deezer","items",0,500,"menu:deezer","item_id:3.0"]' |
  jq -r --arg n "$PL_NAME" '[.result.item_loop[]? | .text] | index($n) // empty')
[ -z "$idx" ] && { echo "\"$PL_NAME\" not found in My collection -> Playlists"; echo "VERDICT: inconclusive"; exit 2; }
ITEM=3.0.$idx

classify() {
  local ids=" $(tr '\n' ' ' <"$1") " bad="" miss=""
  for id in $UNPLAYABLE; do [[ "$ids" == *" $id "* ]] && bad+="$id "; done
  for id in $VIA_FALLBACK; do [[ "$ids" != *" $id "* ]] && miss+="$id "; done
  local n; n=$(wc -w <"$1" | tr -d ' ')
  if [ -z "$bad" ] && [ -z "$miss" ]; then echo "playable ($n tracks)"
  elif [ -n "$bad" ] && [ "$(wc -w <<<"$miss")" -eq 12 ]; then echo "readable ($n tracks)"
  else echo "mixed ($n tracks, unplayable in: ${bad:-none}, Fallback-only missing: ${miss:-none})"; fi
}
browse() {
  rpc $P '["deezer","items",0,500,"menu:deezer","item_id:'$ITEM'"]' |
    jq -r '.result.item_loop[]?.presetParams.favorites_url // empty' | grep -oE '[0-9]+' >"$1"
}
queue() {
  rpc $P '["playlist","clear"]' >/dev/null
  rpc $P '["playlist","add","deezer://playlist:'$PL_ID'"]' >/dev/null
  # the playlist is exploded asynchronously: wait until the queue length stays the same for 1 s
  local last=-1 n
  for _ in $(seq 1 40); do
    sleep 0.5; n=$(rpc $P '["playlist","tracks","?"]' | jq -r '.result._tracks // 0')
    [ "$n" -gt 0 ] && [ "$n" = "$last" ] && break; last=$n
  done
  rpc $P '["status",0,500,"tags:u"]' | jq -r '.result.playlist_loop[]?.url // empty' | grep -oE '[0-9]+' >"$1"
}
ts() { grep -oE '^\[[0-9: .-]+\]' | tr -d '[]'; }

red=0; inside_total=0; runs_done=0
rpc $P '["stop"]' >/dev/null
for run in $(seq 1 "$RUNS"); do
  OFF=$(wc -c <"$LOG")
  docker restart lms-deezer-dev >/dev/null
  for _ in $(seq 1 600); do
    rpc "" '["players",0,9]' 2>/dev/null | jq -e '.result.players_loop[]?|select(.playerid=="'$P'")' >/dev/null 2>&1 && break
    sleep 0.02
  done
  browse "$TMP/browse" & queue "$TMP/queue"; wait

  # wait for refreshArl, then read the timeline of this start from the log
  for _ in $(seq 1 30); do tail -c +$((OFF + 1)) "$LOG" >"$TMP/log"; grep -q "Refreshed Arl for user" "$TMP/log" && break; sleep 1; done
  if ! grep -q "Refreshed Arl for user" "$TMP/log" || sed -n '1,/Refreshed Arl for user/p' "$TMP/log" | grep -q "API::Async.*Error:"; then
    echo "run $run: refreshArl failed or did not finish, run skipped"; continue
  fi
  init=$(grep "Server done init" "$TMP/log" | head -1 | ts)
  arl=$(grep "Refreshed Arl for user" "$TMP/log" | head -1 | ts)
  asks=$(grep "Using cache key 'deezer_resp:/playlist/$PL_ID/tracks:limit" "$TMP/log" | ts)
  inside=$(while read -r d t; do [ -n "$t" ] && [[ "$d $t" < "$arl" ]] && echo x; done <<<"$asks" | wc -l | tr -d ' ')
  inside_total=$((inside_total + inside)); runs_done=$((runs_done + 1))
  echo "run $run: web up ${init#* }, ARL ${arl#* }, requests inside the window: $inside of $(grep -c . <<<"$asks")"
  for what in browse queue; do
    c=$(classify "$TMP/$what"); printf "  %-6s in the window:    %s\n" "$what" "$c"
    [[ "$c" == playable* ]] || red=1
  done

  # after the window: a readable result must not outlive it
  browse "$TMP/browse"; queue "$TMP/queue"
  for what in browse queue; do
    c=$(classify "$TMP/$what"); printf "  %-6s after the window: %s\n" "$what" "$c"
    [[ "$c" == playable* ]] || red=1
  done
done
rpc $P '["playlist","clear"]' >/dev/null

echo "runs: $runs_done, requests inside the window: $inside_total"
[ $red = 1 ] && { echo "VERDICT: RED"; exit 1; }
[ "$inside_total" = 0 ] && { echo "VERDICT: inconclusive (no request reached the plugin before the ARL)"; exit 2; }
echo "VERDICT: green"
