#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 <svc-or-pod> <local-port> <remote-port> -- <smoke-test-cmd...>"
  exit 2
fi

SVC="$1"
LOCAL_PORT="$2"
REMOTE_PORT="$3"
shift 3
if [ "$1" != "--" ]; then
  echo "Expected -- before smoke-test command" >&2
  exit 2
fi
shift 1
SMOKE_CMD=( "$@" )

PF_LOG="$(mktemp /tmp/pf.log.XXXXXX)"
PF_PID=""

cleanup() {
  set +e
  if [ -n "$PF_PID" ]; then
    echo "Stopping port-forward (PID $PF_PID)..."
    kill "$PF_PID" 2>/dev/null || true
    wait "$PF_PID" 2>/dev/null || true
  fi
  [ -f "$PF_LOG" ] && echo "==== port-forward log ====" && tail -n 200 "$PF_LOG" || true
}
trap cleanup EXIT INT TERM

echo "Starting port-forward for $SVC on localhost:$LOCAL_PORT → remote $REMOTE_PORT"
kubectl -n dev port-forward "$SVC" "$LOCAL_PORT":"$REMOTE_PORT" >"$PF_LOG" 2>&1 &
PF_PID=$!
sleep 3

# verify the port-forward actually started
if ! netstat -ano | grep ":${LOCAL_PORT}" >/dev/null 2>&1; then
  echo "Port-forward did not start properly, dumping log:" >&2
  tail -n 200 "$PF_LOG" || true
  exit 1
fi

echo "Running smoke-test command: ${SMOKE_CMD[*]}"
"${SMOKE_CMD[@]}"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "Smoke test failed with exit code $EXIT_CODE; showing log:" >&2
  tail -n 200 "$PF_LOG" || true
  exit $EXIT_CODE
fi

echo "Smoke test succeeded."
exit 0
