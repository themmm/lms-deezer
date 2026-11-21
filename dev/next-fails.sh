#!/bin/bash
# Feedback loop for fork #17 (LMS core, no plugin involved): when the *next* track cannot be
# started, LMS should skip it and play the one after.
# Queues three entries (local WAV, broken entry, local WAV), plays from the first and watches
# whether the player reaches the third. Two cases:
#   control: the second entry is a local file that is missing on disk. It fails in _Stream (open),
#            which drops the failed song from the song queue, so LMS skips it. Expected to pass.
#   test:    the second entry is an unreachable http:// URL. It fails in getNextSong (scanUrl),
#            i.e. NextTrackError -> _NextIfMore. In LMS 9.1+ the failed song stays in the song
#            queue, _NextIfMore logs "streaming track not started yet" and playback stops when the
#            current track ends. Deezer tracks without rights fail the same way (fork #11).
# The verdict is the test case's. exit 1 = RED, exit 2 = inconclusive (no player, no answer, or
# the control case failed, which means the setup itself is broken).
D=$(cd "$(dirname "$0")" && pwd); P=02:00:00:00:00:08; LOG=$D/config/logs/server.log
M=$D/music/repro17
rpc() { "$D/rpc.sh" "$@"; }

if [ ! -f "$M/3-third.wav" ]; then
  mkdir -p "$M"
  python3 -I - "$M" <<'EOF'
import math, struct, sys, wave
for name, f in (("1-first", 440), ("2-missing", 550), ("3-third", 660)):
    w = wave.open(f"{sys.argv[1]}/{name}.wav", "wb")
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(44100)
    w.writeframes(b"".join(struct.pack("<hh", v, v) for v in
                           (int(8000 * math.sin(2 * math.pi * f * i / 44100)) for i in range(44100 * 30))))
    w.close()
EOF
fi
[ -f "$M/2-missing.wav.hidden" ] && mv "$M/2-missing.wav.hidden" "$M/2-missing.wav"
trap 'mv "$M/2-missing.wav.hidden" "$M/2-missing.wav" 2>/dev/null' EXIT

rpc "" '["players",0,9]' | jq -e '.result.players_loop[]?|select(.playerid=="'$P'")' >/dev/null ||
  { echo "test player not connected (./player.sh &)"; echo "VERDICT: inconclusive"; exit 2; }
rpc "" '["debug","player.source","INFO"]' >/dev/null

# run_case <label> <url of the second entry> [hide]; sets $result to reached|stopped|nostart|noqueue
run_case() {
  local label=$1 second=$2 hide=$3 off s last="" seen="" n
  echo "== $label: second entry $second${hide:+ (file hidden on disk)}"
  off=$(wc -c <"$LOG")
  rpc $P '["stop"]' >/dev/null; rpc $P '["playlist","clear"]' >/dev/null
  for u in file:///music/repro17/1-first.wav "$second" file:///music/repro17/3-third.wav; do
    rpc $P '["playlist","add","'$u'"]' >/dev/null
  done
  n=$(rpc $P '["playlist","tracks","?"]' | jq -r '.result._tracks // 0')
  [ "$n" = 3 ] || { echo "  queue has ${n:-no answer} entries, expected 3"; result=noqueue; return; }
  [ -n "$hide" ] && mv "$M/2-missing.wav" "$M/2-missing.wav.hidden"

  rpc $P '["playlist","index",0]' >/dev/null
  result=nostart
  for _ in $(seq 1 240); do
    s=$(rpc $P '["status","-",1]' | jq -r '.result | "\(.mode) \(.playlist_cur_index)"')
    [ "$s" != "$last" ] && { echo "  $(date +%T) mode/index: $s"; last=$s; }
    case "$s" in
      "play 2") result=reached; break ;;
      stop*) [ -n "$seen" ] && { result=stopped; break; } ;;
      play*) seen=1 ;;
    esac
    sleep 0.5
  done
  rpc $P '["stop"]' >/dev/null
  [ -n "$hide" ] && mv "$M/2-missing.wav.hidden" "$M/2-missing.wav"

  echo "  server.log:"
  tail -c +$((off + 1)) "$LOG" | grep -E "stream failed to open|streaming track not started|Song queue is now|NextTrackError|Stopped in|scanning URL|Giving up" |
    grep -v "resetSongqueue" | sed -E 's/^\[[0-9-]+ ([0-9:.]+)\] /    \1 /' | head -15
  echo "  result: $result"
}

run_case control file:///music/repro17/2-missing.wav hide; control=$result
run_case test http://127.0.0.1:1/unreachable.mp3; test=$result
rpc $P '["playlist","clear"]' >/dev/null

echo "control (missing local file): $control, test (unreachable URL): $test"
[ "$control" = reached ] || { echo "control case did not reach the third track, setup broken"; echo "VERDICT: inconclusive"; exit 2; }
case $test in
  reached) echo "VERDICT: green"; exit 0 ;;
  stopped) echo "VERDICT: RED"; exit 1 ;;
  *) echo "VERDICT: inconclusive"; exit 2 ;;
esac
