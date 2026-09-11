#!/bin/bash

set -euo pipefail

ASN=$(cat /opt/security-scanner/config/asn.txt)
[[ "$ASN" =~ ^AS[0-9]+$ ]] || { echo "Configure config/asn.txt with your authorized ASN." >&2; exit 1; }
OUT="/opt/security-scanner/data/prefixes.txt"

mkdir -p "$(dirname "$OUT")"

echo "[+] Fetching prefixes for $ASN from RIPEstat..."

curl -fsS --retry 2 --connect-timeout 15 --max-time 120 "https://stat.ripe.net/data/announced-prefixes/data.json?resource=${ASN}" \
| jq -r '.data.prefixes[].prefix' \
| grep '\.' \
| sort -u > "$OUT"

echo
echo "[+] Saved to: $OUT"
echo "[+] Prefix count:"
wc -l < "$OUT"

echo
echo "[+] Prefixes:"
cat "$OUT"
