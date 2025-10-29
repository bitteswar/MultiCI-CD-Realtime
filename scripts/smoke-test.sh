#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
HEALTH_PATH="${2:-/actuator/health}"
API_PATH="${3:-/api/hello}"

RETRIES="${RETRIES:-10}"
DELAY="${DELAY:-5}"
TIMEOUT_CURL=5

echo "PP_URL:   ${BASE_URL}${API_PATH}"
echo "HEALTH:   ${HEALTH_PATH}"
echo "RETRIES:  ${RETRIES}"
echo "DELAY(s): ${DELAY}"
echo "Checking health endpoint..."

for attempt in $(seq 1 "$RETRIES"); do
  echo "Attempt ${attempt}/${RETRIES}: $(date +'%Y-%m-%dT%H:%M:%S')"
  # Use curl to get status code and first bytes
  HTTP_RESPONSE="$(curl -sS -m ${TIMEOUT_CURL} -w "%{http_code}" -o /tmp/_smoke_body.txt "${BASE_URL}${HEALTH_PATH}" || true)"
  BODY="$(head -c 240 /tmp/_smoke_body.txt || true)"
  echo "  HTTP ${HTTP_RESPONSE}"
  echo "  Body (first 240 chars):"
  echo "$BODY" | sed -n '1,4p' || true

  # If we got 200 and expected JSON containing "status" or similar, pass
  if [ "$HTTP_RESPONSE" = "200" ]; then
    # quick sanity: ensure it's not HTML (Jenkins) — we expect JSON or simple text.
    if echo "$BODY" | grep -q -i '<html\|<!DOCTYPE'; then
      echo "  WARNING: Health endpoint returned HTML (looks like Jenkins/UI). Not healthy yet."
    else
      echo "Healthy (200 + not HTML). Now checking application endpoint..."
      # verify app endpoint too
      API_CODE="$(curl -sS -m ${TIMEOUT_CURL} -o /tmp/_api_body.txt -w "%{http_code}" "${BASE_URL}${API_PATH}" || true)"
      API_BODY="$(head -c 240 /tmp/_api_body.txt || true)"
      echo "  API ${API_CODE}"
      if [ "$API_CODE" = "200" ]; then
        echo "Application API returned 200. Smoke-test PASSED."
        exit 0
      else
        echo "Application API returned ${API_CODE}. Keep waiting..."
      fi
    fi
  fi

  echo "Not healthy yet. Sleeping ${DELAY}s..."
  sleep "${DELAY}"
done

echo "ERROR: Health endpoint did not return 200 after ${RETRIES} attempts."
echo "Last response body (first 2KB):"
cat /tmp/_smoke_body.txt || true
exit 1
