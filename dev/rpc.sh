#!/bin/bash
# usage: rpc.sh <playerid|""> '<json array of command>'
curl -s -m 10 -X POST -H 'Content-Type: application/json' \
  -d "{\"id\":1,\"method\":\"slim.request\",\"params\":[\"$1\",$2]}" http://localhost:9000/jsonrpc.js
