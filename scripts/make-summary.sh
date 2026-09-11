#!/bin/bash
set -euo pipefail

RESULTS="/opt/security-scanner/data/results"

# Require the exact completed scan; never select a different run implicitly.
SCAN_ID="${1:-}"
[[ "$SCAN_ID" =~ ^[0-9]{8}_[0-9]{6}$ ]] || { echo "Usage: $0 <YYYYMMDD_HHMMSS>" >&2; exit 1; }
LAST_SCAN="$RESULTS/full_$SCAN_ID"
[[ "$(cat "$LAST_SCAN/status.txt" 2>/dev/null)" == COMPLETED ]] || { echo "Scan is not COMPLETED." >&2; exit 1; }

PORTS_FILE="$LAST_SCAN/ports.txt"
HTTP_FILE="$LAST_SCAN/httpx.jsonl"
NUCLEI_FILE="$LAST_SCAN/nuclei.jsonl"
SUMMARY="$LAST_SCAN/summary.txt"

PORTS=0
HOSTS=0
HTTP=0
CRITICAL=0

[ -f "$PORTS_FILE" ] && PORTS=$(wc -l < "$PORTS_FILE")
[ -f "$PORTS_FILE" ] && HOSTS=$(cut -d: -f1 "$PORTS_FILE" | sort -u | wc -l)
[ -f "$HTTP_FILE" ] && HTTP=$(wc -l < "$HTTP_FILE")
[ -f "$NUCLEI_FILE" ] && CRITICAL=$(wc -l < "$NUCLEI_FILE")

{
    echo "FULL SECURITY SCAN"
    echo "=============================="
    echo "SCAN ID: $SCAN_ID"
    echo
    echo "Unique hosts: $HOSTS"
    echo "Open ports:  $PORTS"
    echo "HTTP/HTTPS:      $HTTP"
    echo "Critical:        $CRITICAL"
    echo
    echo "HOSTS / OPEN PORTS"
    echo "=============================="

    if [ -s "$PORTS_FILE" ]; then
        sort -V "$PORTS_FILE"
    else
        echo "No open ports found."
    fi

} > "$SUMMARY"

echo "SUMMARY=$SUMMARY"
echo "SCAN_ID=$SCAN_ID"
echo "HOSTS=$HOSTS"
echo "PORTS=$PORTS"
echo "HTTP=$HTTP"
echo "CRITICAL=$CRITICAL"
