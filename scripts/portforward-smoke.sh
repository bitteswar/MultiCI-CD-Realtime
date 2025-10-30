#!/usr/bin/env bash
# portforward-smoke.sh
# Usage:
#   ./scripts/portforward-smoke.sh <svc-or-pod> <local-port> <remote-port> -- <smoke-test-cmd...>
# Example:
#   ./scripts/portforward-smoke.sh svc/sample-app-sample-app-svc 18080 8080 -- bash ./scripts/smoke-test.sh "http://localhost:18080" "/actuator/health" "/api/hello"

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
  echo "Expected '--' before smoke test command" >&2
  exit 2
fi
shift 1
SMOKE_CMD=( "$@" )

# Probe configuration (tuneable via env)
RETRIES="${PF_RETRIES:-10}"
DELAY="${PF_DELAY:-3}"        # seconds
HEALTH_PATH="${PF_HEALTH_PATH:-/actuator/health}"
# optional full URL path check; if SMOKE_CMD already checks health, you can leave as-is.

PF_LOG="$(mktemp /tmp/pf.log.XXXXXX)"
PF_PID=""

cleanup() {
  set +e
  if [ -n "$PF_PID" ]; then
    echo "Stopping port-forward (pid $PF_PID)..."
    kill "$PF_PID" 2>/dev/null || true
    wait "$PF_PID" 2>/dev/null || true
  fi
  [ -f "$PF_LOG" ] && echo "==== port-forward log (last 200 lines) ====" && tail -n 200 "$PF_LOG" || true
}
trap cleanup EXIT INT TERM

echo "Starting port-forward for $SVC -> localhost:${LOCAL_PORT} (remote ${REMOTE_PORT})"
kubectl -n dev port-forward "$SVC" "${LOCAL_PORT}:${REMOTE_PORT}" >"$PF_LOG" 2>&1 &
PF_PID=$!

# Give port-forward a moment to start
sleep 2

# Function: probe with curl if available, otherwise fallback to simple socket/listen check
probe_http() {
  local url="http://localhost:${LOCAL_PORT}${HEALTH_PATH}"
  if command -v curl >/dev/null 2>&1; then
    # use curl to check for HTTP 200 (or any 2xx)
    if curl -s -f -o /dev/null "$url"; then
      return 0
    else
      return 1
    fi
  else
    # fallback: check socket is listening (portable netstat) and attempt a raw TCP connect
    if netstat -an 2>/dev/null | grep -E ":${LOCAL_PORT}[^0-9]" >/dev/null 2>&1; then
      # try to write a minimal HTTP GET using /dev/tcp if available
      if (exec 3<>/dev/tcp/127.0.0.1/${LOCAL_PORT}) 2>/dev/null; then
        printf 'GET %s HTTP/1.0\r\nHost: localhost\r\n\r\n' "$HEALTH_PATH" >&3
        # read first line of response
        head -n 1 <&3 | grep -E 'HTTP/[0-9\.]+\s+2[0-9][0-9]' >/dev/null 2>&1 && return 0 || return 1
      else
        # no /dev/tcp support; just return success if netstat shows listening
        return 0
      fi
    fi
    return 1
  fi
}

echo "Waiting up to $((RETRIES*DELAY))s for localhost:${LOCAL_PORT} to respond to ${HEALTH_PATH} (retries=$RETRIES, delay=${DELAY}s)..."
i=0
while [ $i -lt "$RETRIES" ]; do
  if probe_http; then
    echo "Port-forward probe success on attempt $((i+1))."
    break
  fi
  i=$((i+1))
  echo "Attempt $i/$RETRIES: not ready yet. Sleeping ${DELAY}s..."
  sleep "$DELAY"
done

if [ $i -ge "$RETRIES" ]; then
  echo "Port-forward did not start properly, dumping log:"
  tail -n 200 "$PF_LOG" || true
  exit 1
fi

# Run the smoke-test command (array - preserves args)
echo "Running smoke test: ${SMOKE_CMD[*]}"
"${SMOKE_CMD[@]}"
SMOKE_EXIT=$?

if [ $SMOKE_EXIT -ne 0 ]; then
  echo "Smoke test failed with exit code $SMOKE_EXIT; dumping port-forward log:"
  tail -n 200 "$PF_LOG" || true
  exit $SMOKE_EXIT
fi

echo "Smoke test succeeded."
exit 0
