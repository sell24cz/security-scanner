#!/bin/bash
set -euo pipefail

BASE="/opt/security-scanner"
SCAN_ID=$(date +%Y%m%d_%H%M%S)

OUT="$BASE/data/results/full_${SCAN_ID}"
mkdir -p "$OUT"

chmod 2775 "$OUT"


echo "STARTING" > "$OUT/status.txt"

nohup env SCAN_ID="$SCAN_ID" \
  "$BASE/scripts/run-full-scan.sh" \
  > "$OUT/scan.log" 2>&1 < /dev/null &

PID=$!

echo "$PID" > "$OUT/pid.txt"

echo "SCAN_STARTED"
echo "SCAN_ID=$SCAN_ID"
echo "PID=$PID"
echo "STATUS_FILE=$OUT/status.txt"
echo "LOG_FILE=$OUT/scan.log"
