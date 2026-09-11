#!/bin/bash
set -euo pipefail

SCAN_ID="${1:-}"
[[ "$SCAN_ID" =~ ^[0-9]{8}_[0-9]{6}$ ]] || { echo "Invalid SCAN_ID." >&2; exit 1; }

if [ -z "$SCAN_ID" ]; then
    echo "Usage: $0 <SCAN_ID>"
    exit 1
fi

BASE="/opt/security-scanner/data/results/full_${SCAN_ID}"

if [ ! -d "$BASE" ]; then
    echo "STATUS=NOT_FOUND"
    exit 2
fi

STATUS=$(cat "$BASE/status.txt" 2>/dev/null || echo "UNKNOWN")

echo "SCAN_ID=$SCAN_ID"
echo "STATUS=$STATUS"

if [ -f "$BASE/summary.env" ]; then
    cat "$BASE/summary.env"
fi

if [ -f "$BASE/critical-summary.txt" ]; then
    echo "CRITICAL_LIST_BEGIN"
    cat "$BASE/critical-summary.txt"
    echo "CRITICAL_LIST_END"
fi
