#!/bin/bash
# Feedback loop for playlist playability (fallback resolution, upstream PR #81) on "Love Machine".
# 1. Loads the playlist into the queue and checks which tracks are in it:
#    - must NOT contain tracks without rights and without fallback (2540822, 3083376)
#    - must contain the readable=false tracks that play via fallback (12 ids below)
# 2. Plays "Lovemachine" to its natural end and checks that playback goes on to a later track.
# Needs the test player running fast (PACE=6000000 ./player.sh). exit 1 = RED.
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08
PL=deezer://playlist:13715702701
UNPLAYABLE="2540822 3083376"
VIA_FALLBACK="2884478 5425390 145534376 471798752 70221941 2270632 26169641 145534390 916462 58082321 6776198 5425389"
rpc() { "$D/rpc.sh" "$@"; }
red=0

rpc $P '["stop"]' >/dev/null; rpc $P '["playlist","clear"]' >/dev/null
rpc $P '["playlist","add","'$PL'"]' >/dev/null; sleep 5
n=$(rpc $P '["playlist","tracks","?"]' | jq -r '.result._tracks')
ids=" "; for ((i = 0; i < n; i++)); do
  ids+="$(rpc $P '["playlist","path",'$i',"?"]' | jq -r '.result._path // ""' | grep -oE '[0-9]+' | head -1) "
done
echo "queue entries: $n"
bad=""; for id in $UNPLAYABLE; do [[ "$ids" == *" $id "* ]] && bad+="$id "; done
miss=""; for id in $VIA_FALLBACK; do [[ "$ids" != *" $id "* ]] && miss+="$id "; done
echo "unplayable tracks in queue:        ${bad:-none}"; [ -n "$bad" ] && red=1
echo "fallback-playable tracks missing:  $(wc -w <<<"$miss" | tr -d ' ') of 12 ${miss:+($miss)}"; [ -n "$miss" ] && red=1

# transition test: play "Lovemachine" (661301) to its end
start=-1; for ((i = 0; i < n; i++)); do [ "$(rpc $P '["playlist","path",'$i',"?"]' | jq -r .result._path)" = "deezer://661301.flc" ] && start=$i && break; done
rpc $P '["playlist","index",'$start']' >/dev/null
# Lovemachine is 515 s long, about 25-30 s at the fast pace, longer when the stream starts slowly:
# watch up to 120 s, and 5 s past the first track change, so that a stop on the next track is seen
last=""; moved=0; for s in $(seq 1 120); do
  sleep 1; S=$(rpc $P '["status","-",1,"tags:a"]')
  line=$(jq -r '.result | "mode=\(.mode) idx=\(.playlist_cur_index // "-") \(.playlist_loop[0].title // "-")"' <<<"$S")
  [ "$line" != "$last" ] && echo "  t+${s}s $line"; last=$line
  grep -q "mode=stop" <<<"$line" && break
  [ "$(jq -r '.result.playlist_cur_index // 0' <<<"$S")" -gt "$start" ] && moved=$((moved + 1))
  [ $moved -ge 5 ] && break
done
rpc $P '["stop"]' >/dev/null
idx=$(jq -r '.result.playlist_cur_index // 0' <<<"$S")
if grep -q "mode=stop" <<<"$last"; then echo "transition after Lovemachine:     STOPPED"; red=1
elif [ "$idx" -gt "$start" ]; then echo "transition after Lovemachine:     plays on"
else echo "transition after Lovemachine:     still playing after 120 s"; [ $red = 0 ] && { echo "VERDICT: inconclusive"; exit 2; }; fi

[ $red = 1 ] && { echo "VERDICT: RED"; exit 1; }
echo "VERDICT: green"
