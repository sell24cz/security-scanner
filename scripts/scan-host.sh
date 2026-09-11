#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <IP>"
    exit 1
fi

TARGET="$1"
python3 - "$TARGET" <<'PY'
import ipaddress, sys
ipaddress.IPv4Address(sys.argv[1])
PY
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT="/data/results/${TARGET}_${TIMESTAMP}"
HOST_OUT="/opt/security-scanner/data/results/${TARGET}_${TIMESTAMP}"

mkdir -p "$HOST_OUT"

echo "[1/3] Naabu..."
docker exec security-scanner naabu \
  -host "$TARGET" \
  -top-ports 100 \
  -silent \
  -o "$OUT/ports.txt"

echo "[2/3] httpx..."
docker exec security-scanner httpx \
  -l "$OUT/ports.txt" \
  -silent \
  -title \
  -tech-detect \
  -status-code \
  -server \
  -json \
  -o "$OUT/httpx.jsonl"

docker exec security-scanner sh -c \
  "jq -r '.url' '$OUT/httpx.jsonl' > '$OUT/urls.txt'"

echo "[3/3] Nuclei..."
docker exec security-scanner nuclei \
  -l "$OUT/urls.txt" \
  -t /data/nuclei-templates \
  -severity critical \
  -ni \
  -c 50 \
  -rate-limit 150 \
  -timeout 10 \
  -retries 1 \
  -jsonl \
  -o "$OUT/nuclei.jsonl"

PORTS=$(wc -l < "$HOST_OUT/ports.txt")
HTTP=$(wc -l < "$HOST_OUT/httpx.jsonl")
CRITICAL=$(wc -l < "$HOST_OUT/nuclei.jsonl")

echo
echo "SCAN_OK"
echo "TARGET=$TARGET"
echo "RESULT_DIR=$OUT"
echo "PORTS=$PORTS"
echo "HTTP=$HTTP"
echo "CRITICAL=$CRITICAL"
