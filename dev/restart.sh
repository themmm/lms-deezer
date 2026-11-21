#!/bin/bash
# Restart the LMS container and wait until the test player is connected and the Deezer account
# context really has an ARL. refreshArl logs "Refreshed Arl" even when its requests failed (e.g. DNS
# not ready right after container start), so any Async error before that line counts as a failed
# start and the container is restarted again (up to 3 times). A failed start must not be left
# running: without an ARL the plugin's gw calls loop (fork issue #6).
D=$(cd "$(dirname "$0")" && pwd); LOG=$D/config/logs/server.log
for attempt in 1 2 3; do
  OFF=$(wc -c <"$LOG")
  docker restart lms-deezer-dev >/dev/null
  for _ in $(seq 1 90); do
    new=$(tail -c +$((OFF + 1)) "$LOG")
    if grep -q "Refreshed Arl for user" <<<"$new"; then
      if sed -n '1,/Refreshed Arl for user/p' <<<"$new" | grep -q "API::Async.*Error:"; then
        echo "attempt $attempt: refreshArl failed ($(grep -o 'Error: [^"]*' <<<"$new" | head -1 | cut -c1-70)), restarting"
        docker stop lms-deezer-dev >/dev/null; sleep 3; continue 2
      fi
      if "$D/rpc.sh" "" '["players",0,9]' | jq -e '.result.players_loop[]?|select(.playerid=="02:00:00:00:00:08")' >/dev/null; then
        "$D/rpc.sh" "" '["debug","plugin.deezer","INFO"]' >/dev/null; echo "LMS ready"; exit 0
      fi
    fi
    sleep 1
  done
done
docker stop lms-deezer-dev >/dev/null; echo "LMS not ready after 3 attempts, stopped"; exit 1
