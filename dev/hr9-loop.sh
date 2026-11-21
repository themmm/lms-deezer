#!/bin/bash
# Feedback loop for issue #9: does server.log contain the ARL or other session secrets?
# Sets plugin.deezer to <level> in log.conf, restarts LMS (new session + refreshArl at startup),
# exercises the settings page (bad ARL, then re-adding the real one), plays a track and Flow,
# then counts secrets in the log written since the restart. Prints counts and log locations, never values.
# usage: hr9-loop.sh [DEBUG|INFO|WARN|ERROR]     exit 1 = RED (an ARL or ARL-shaped string is in the log)
set -u
D=$(cd "$(dirname "$0")" && pwd)
LEVEL=${1:-DEBUG}
LOG=$D/config/logs/server.log
PREFS=$D/config/prefs/plugin/deezer.prefs
P=02:00:00:00:00:08
PRIV=$(mktemp -d); chmod 700 "$PRIV"; trap 'rm -rf "$PRIV"' EXIT
arls() { grep -E '^[[:space:]]+arl:' "$PREFS" | awk '{print $2}' >>"$PRIV/arls"; }
rpc() { "$D/rpc.sh" "$@"; }

arls
sed -i '' -E "s/^(log4perl\.logger\.plugin\.deezer = ).*/\1$LEVEL/" "$D/config/prefs/log.conf"
OFF=$(wc -c <"$LOG")
docker restart lms-deezer-dev >/dev/null
for _ in $(seq 1 60); do rpc "" '["serverstatus",0,0]' >/dev/null 2>&1 && break; sleep 2; done
for _ in $(seq 1 30); do rpc "" '["players",0,9]' | jq -e --arg p $P '.result.players_loop[]?|select(.playerid==$p)' >/dev/null && break; sleep 1; done

# settings page: a wrong ARL (192 hex chars, not a real account), then the real one again
FAKE=$(printf 'f%.0s' $(seq 1 192))
curl -s -o /dev/null -m 20 http://localhost:9000/plugins/Deezer/settings.html --data "addAccount=1&arl=$FAKE"
head -1 "$PRIV/arls" | tr -d '\n' >"$PRIV/real"
curl -s -o /dev/null -m 20 http://localhost:9000/plugins/Deezer/settings.html --data "addAccount=1" --data-urlencode "arl@$PRIV/real"

for u in deezer://67238735.flac deezer://user.flow; do
  rpc $P '["playlist","play","'$u'"]' >/dev/null; sleep 6
done
rpc $P '["stop"]' >/dev/null
sleep 2; arls; sort -u "$PRIV/arls" -o "$PRIV/arls"; echo "$FAKE" >"$PRIV/fake"

NEW=$PRIV/new.log; tail -c +$((OFF + 1)) "$LOG" >"$NEW"
# attribute every matching line (also continuation lines of multi-line dumps) to the log call that wrote it
loc_re() { awk -v re="$1" 'match($0, /^\[[^]]+\] [A-Za-z:_]+ \([0-9]+\)/) { cur = substr($0, RSTART, RLENGTH); sub(/^\[[^]]+\] /, "", cur) } $0 ~ re { print cur }' "$NEW" | sort | uniq -c | sed 's/^/      /'; }
loc_f() { awk 'NR==FNR { k[$0]; next } match($0, /^\[[^]]+\] [A-Za-z:_]+ \([0-9]+\)/) { cur = substr($0, RSTART, RLENGTH); sub(/^\[[^]]+\] /, "", cur) } { for (x in k) if (index($0, x)) { print cur; break } }' "$1" "$NEW" | sort | uniq -c | sed 's/^/      /'; }
count() { local label=$1 re=$2 n; n=$(grep -cE -- "$re" "$NEW"); printf '%-44s %s\n' "$label" "$n"; [ "$n" -gt 0 ] && loc_re "$re"; }

echo "=== level=$LEVEL  log bytes=$(wc -c <"$NEW")  plugin lines=$(grep -c 'Plugins::Deezer' "$NEW")"
n_real=$(grep -cFf "$PRIV/arls" "$NEW"); printf '%-44s %s\n' "real ARL (current or rotated)" "$n_real"; [ "$n_real" -gt 0 ] && loc_f "$PRIV/arls"
n_fake=$(grep -cFf "$PRIV/fake" "$NEW"); printf '%-44s %s\n' "rejected ARL from settings" "$n_fake"; [ "$n_fake" -gt 0 ] && loc_f "$PRIV/fake"
count "any 192-hex string (ARL-shaped)" '[0-9a-fA-F]{192}'; n_hex=$(grep -cE '[0-9a-fA-F]{192}' "$NEW")
count "sid / SESSION_ID value" "(SESSION_ID|[^a-z]sid)[\"']?[[:space:]]*(=>|=|:)[[:space:]]*[\"']?[0-9a-z]{20,}"
count "license_token value" "license_token[\"']?[[:space:]]*(=>|=|:)[[:space:]]*[\"']?[A-Za-z0-9_-]{20,}"
count "USER_TOKEN value" "USER_TOKEN[\"']?[[:space:]]*(=>|=|:)[[:space:]]*[\"']?[0-9a-f]{20,}"
count "api_token / checkForm value" "(api_token=|checkForm[\"']?[[:space:]]*(=>|:)[[:space:]]*[\"']?)[A-Za-z0-9._-]{20,}"
count "signed stream URL (hdnea=)" 'hdnea='

if [ $((n_real + n_fake + n_hex)) -gt 0 ]; then echo "VERDICT: RED (ARL in server.log)"; exit 1; fi
echo "VERDICT: green (no ARL in server.log)"
