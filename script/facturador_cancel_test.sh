#!/usr/bin/env bash
# Usage:
#   FACTURADOR_USERNAME=... \
#   FACTURADOR_PASSWORD_MD5=... \
#   FACTURADOR_CLIENT_ID=... \
#   FACTURADOR_CLIENT_SECRET=... \
#   EMISOR_ID=208 \
#   UUID=E9D76E96-D269-438A-B38B-56DF9F786C78 \
#   ./script/facturador_cancel_test.sh
#
# Optional overrides:
#   AUTH_BASE_URL     (default: https://authcli.stagefacturador.com)
#   BUSINESS_BASE_URL (default: https://pruebas.stagefacturador.com)
#   MOTIVO            (default: 02)

set -euo pipefail

AUTH_BASE_URL="${AUTH_BASE_URL:-https://authcli.stagefacturador.com}"
BUSINESS_BASE_URL="${BUSINESS_BASE_URL:-https://pruebas.stagefacturador.com}"
MOTIVO="${MOTIVO:-02}"

: "${FACTURADOR_USERNAME:?Set FACTURADOR_USERNAME}"
: "${FACTURADOR_PASSWORD_MD5:?Set FACTURADOR_PASSWORD_MD5}"
: "${FACTURADOR_CLIENT_ID:?Set FACTURADOR_CLIENT_ID}"
: "${FACTURADOR_CLIENT_SECRET:?Set FACTURADOR_CLIENT_SECRET}"
: "${EMISOR_ID:?Set EMISOR_ID}"
: "${UUID:?Set UUID}"

SEPARATOR="HTTPSTATUS"

echo "=== Step 1: Fetch access token ==="
TOKEN_RESPONSE=$(curl -s -w "${SEPARATOR}:%{http_code}" \
  -X POST "${AUTH_BASE_URL}/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "scope=offline_access openid APINegocios" \
  --data-urlencode "username=${FACTURADOR_USERNAME}" \
  --data-urlencode "password=${FACTURADOR_PASSWORD_MD5}" \
  --data-urlencode "client_id=${FACTURADOR_CLIENT_ID}" \
  --data-urlencode "client_secret=${FACTURADOR_CLIENT_SECRET}" \
  --data-urlencode "es_md5=true")

TOKEN_STATUS="${TOKEN_RESPONSE##*${SEPARATOR}:}"
TOKEN_BODY="${TOKEN_RESPONSE%${SEPARATOR}:*}"

echo "HTTP Status: ${TOKEN_STATUS}"
echo "Response: ${TOKEN_BODY}"

if [[ "$TOKEN_STATUS" != "200" ]]; then
  echo "ERROR: Token request failed (HTTP ${TOKEN_STATUS})" >&2
  exit 1
fi

ACCESS_TOKEN=$(echo "$TOKEN_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || true)

if [[ -z "$ACCESS_TOKEN" ]]; then
  ACCESS_TOKEN=$(echo "$TOKEN_BODY" | tr ',' '\n' | grep '"access_token"' | cut -d'"' -f4)
fi

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "ERROR: Could not extract access_token from response" >&2
  exit 1
fi

echo
echo "=== Step 2: Lookup comprobante (buscar_comprobantes) ==="
NOW=$(date +%s)
DATE_FROM=$(( NOW - 86400 * 90 ))
LOOKUP_URL="${BUSINESS_BASE_URL}/BusinessEmision/api/v1/emisores/${EMISOR_ID}/comprobantes?finicial=${DATE_FROM}&ffinal=${NOW}&nocomprobante=0&tipoConfirmacionId=0&skip=0&take=10&uuid=${UUID}"

echo "GET ${LOOKUP_URL}"
LOOKUP_RESPONSE=$(curl -s -w "${SEPARATOR}:%{http_code}" \
  -X GET "${LOOKUP_URL}" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

LOOKUP_STATUS="${LOOKUP_RESPONSE##*${SEPARATOR}:}"
LOOKUP_BODY="${LOOKUP_RESPONSE%${SEPARATOR}:*}"

echo "HTTP Status: ${LOOKUP_STATUS}"
echo "Response: ${LOOKUP_BODY}"

echo
echo "=== Step 3: Cancelar comprobante ==="
CANCEL_URL="${BUSINESS_BASE_URL}/BusinessEmision/api/v1/emisores/${EMISOR_ID}/comprobantes/${UUID}?motivo=${MOTIVO}"

echo "DELETE ${CANCEL_URL}"
CANCEL_RESPONSE=$(curl -s -w "${SEPARATOR}:%{http_code}" \
  -X DELETE "${CANCEL_URL}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d "{\"motivo\":\"${MOTIVO}\"}")

CANCEL_STATUS="${CANCEL_RESPONSE##*${SEPARATOR}:}"
CANCEL_BODY="${CANCEL_RESPONSE%${SEPARATOR}:*}"

echo "HTTP Status: ${CANCEL_STATUS}"
echo "Response: ${CANCEL_BODY}"

echo
echo "=== Done ==="
if [[ "$CANCEL_STATUS" == "200" || "$CANCEL_STATUS" == "204" ]]; then
  echo "SUCCESS: PAC accepted the cancellation request (HTTP ${CANCEL_STATUS})"
else
  echo "FAILURE: PAC returned HTTP ${CANCEL_STATUS}"
fi
