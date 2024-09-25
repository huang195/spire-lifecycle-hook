#!/bin/bash

SOCKET_PATH="/var/run/spire-lifecycle.sock"

STATE=$(cat)

CONTAINER_PID=$(echo "$STATE" | jq -r '.pid')
echo "CONTAINER_PID: $CONTAINER_PID"

echo "INPUT: $STATE"

echo "$CONTAINER_PID" | socat - UNIX-CONNECT:$SOCKET_PATH

exit 0
