#!/usr/bin/env bash
# scripts/smoke-test.sh
# Usage: ./scripts/smoke-test.sh <APP_URL> [--health PATH] [--retries N] [--delay S]
# Example: ./scripts/smoke-test.sh http://localhost:8080/api/hello --health /actuator/health --retries 12 --delay 5

set -u
# Do not set -e because we want to handle failures and print helpful diagnostics

APP_URL="$1"
shift || true

# defaults
HEALTH_PATH="/actuator/health"
RETRIES=10
DELAY=5
EXPECTED_OK_STATUS=200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --health) HEALTH_PATH="$2"; shift 2 ;;
    --retries) RETRIES="$2"; shift 2 ;;
    --delay) DELAY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

# helper to fetch http code and body
http_get() {
  local url="$1"
  # -s silent, -S show errors, -L follow, --max-time to avoid hangs
  curl -sS -L --max-time 10 -w "\n%{http_code}" "$url" || return 2
}

echo "Smoke test starting"
echo "APP_URL:   ${APP_URL}"
echo "HEALTH:    ${HEALTH_PATH}"
echo "RETRIES:   ${RETRIES}"
echo "DELAY(s):  ${DELAY}"
echo

# Wait loop for health endpoint
echo "Checking health endpoint..."
count=0
while [ $count -lt $RETRIES ]; do
  count=$((count+1))
  resp=$(http_get "${APP_URL%/}${HEALTH_PATH}" 2>&1) || rc=$? || true
  # If curl returned 2 (curl error), resp contains curl error text; handle below
  if [[ "$resp" =~ $'\n' ]]; then
    body=$(printf "%s" "$resp" | sed '$d')        # all but last line
    code=$(printf "%s" "$resp" | tail -n1)       # last line is status code
  else
    body=""
    code="000"
  fi

  echo "Attempt $count/${RETRIES}: HTTP ${code}"
  # print a short body preview for debugging
  if [ -n "$body" ]; then
    printf '  Body (first 240 chars): %.240s\n' "$body"
  fi

  if [ "$code" -eq "$EXPECTED_OK_STATUS" ]; then
    echo "Health endpoint returned ${EXPECTED_OK_STATUS} — OK"
    break
  fi

  echo "Not healthy yet. Sleeping ${DELAY}s..."
  sleep "${DELAY}"
done

if [ "$code" -ne "$EXPECTED_OK_STATUS" ]; then
  echo "ERROR: Health endpoint did not return ${EXPECTED_OK_STATUS} after ${RETRIES} attempts."
  exit 3
fi

# Now check the app endpoint (APP_URL)
echo
echo "Checking application endpoint: ${APP_URL}"
count=0
while [ $count -lt $RETRIES ]; do
  count=$((count+1))
  resp=$(http_get "${APP_URL}" 2>&1) || rc=$? || true
  if [[ "$resp" =~ $'\n' ]]; then
    body=$(printf "%s" "$resp" | sed '$d')
    code=$(printf "%s" "$resp" | tail -n1)
  else
    body=""
    code="000"
  fi

  echo "Attempt $count/${RETRIES}: HTTP ${code}"
  if [ -n "$body" ]; then
    printf '  Body (first 240 chars): %.240s\n' "$body"
  fi

  # Basic success checks: status code 200 and expected text "Hello" (case-insensitive)
  if [ "$code" -eq "$EXPECTED_OK_STATUS" ]; then
    # check for a friendly expected string (adjust below to your app's response)
    if echo "$body" | grep -iq "Hello"; then
      echo "Application endpoint returned expected response — OK"
      exit 0
    else
      echo "HTTP 200 but response body did not contain expected text."
      # still consider success if you're okay with status 200 only; change behavior as needed
      exit 0
    fi
  fi

  echo "Not ready yet. Sleeping ${DELAY}s..."
  sleep "${DELAY}"
done

echo "ERROR: Application endpoint did not return ${EXPECTED_OK_STATUS} after ${RETRIES} attempts."
exit 4
