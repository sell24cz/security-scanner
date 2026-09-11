#!/bin/bash
set -euo pipefail

ASN=$(cat /opt/security-scanner/config/asn.txt)
[[ "$ASN" =~ ^AS[0-9]+$ ]] || { echo "Configure config/asn.txt with your authorized ASN." >&2; exit 1; }

SCAN_ID="${SCAN_ID:-$(date +%Y%m%d_%H%M%S)}"
[[ "$SCAN_ID" =~ ^[0-9]{8}_[0-9]{6}$ ]] || { echo "Invalid SCAN_ID." >&2; exit 1; }

BASE="/opt/security-scanner"
DATA="$BASE/data"

OUT="/data/results/full_${SCAN_ID}"
HOST_OUT="$DATA/results/full_${SCAN_ID}"

PREFIXES="$DATA/prefixes.txt"
COLLAPSED="$DATA/prefixes-collapsed.txt"
CONTAINER_COLLAPSED="/data/prefixes-collapsed.txt"

mkdir -p "$HOST_OUT"
chmod 2775 "$HOST_OUT"

fail_scan() {
    echo "FAILED" > "$HOST_OUT/status.txt"

    echo
    echo "SCAN_FAILED"
    echo "SCAN_ID=$SCAN_ID"
}

trap fail_scan ERR

echo "RUNNING" > "$HOST_OUT/status.txt"

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo "========================================"
echo "FULL SECURITY SCAN"
echo "ASN=$ASN"
echo "SCAN_ID=$SCAN_ID"
echo "START=$START_TIME"
echo "========================================"

echo
echo "[1/6] Fetching prefixes $ASN..."
"$BASE/scripts/get-prefixes.sh"

echo
echo "[2/6] Collapsing IPv4 prefixes..."

python3 - "$PREFIXES" "$COLLAPSED" <<'PY'
import sys
import ipaddress

src = sys.argv[1]
dst = sys.argv[2]

with open(src) as f:
    networks = [
        ipaddress.ip_network(line.strip())
        for line in f
        if line.strip()
    ]

networks = [
    n for n in networks
    if isinstance(n, ipaddress.IPv4Network)
]

collapsed = list(ipaddress.collapse_addresses(networks))

with open(dst, "w") as f:
    for network in collapsed:
        f.write(str(network) + "\n")

print("Unique prefixes:", len(collapsed))
PY

PREFIX_COUNT=$(wc -l < "$COLLAPSED")

PREFIX_IPS=$(python3 - "$COLLAPSED" <<'PY'
import sys
import ipaddress

total = 0

with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()

        if line:
            total += ipaddress.ip_network(line).num_addresses

print(total)
PY
)

echo "PREFIX_COUNT=$PREFIX_COUNT"
echo "PREFIX_IPS=$PREFIX_IPS"

echo
echo "[3/6] Updating Nuclei templates..."

docker exec security-scanner nuclei \
  -update-templates \
  -ud /data/nuclei-templates

echo
echo "[4/6] Naabu - FULL $PREFIX_IPS IP..."

touch "$HOST_OUT/ports.txt"

docker exec security-scanner naabu \
  -list "$CONTAINER_COLLAPSED" \
  -top-ports 100 \
  -rate 3000 \
  -silent \
  -o "$OUT/ports.txt"

echo
echo "[5/6] httpx..."

touch "$HOST_OUT/httpx.jsonl"

docker exec security-scanner httpx \
  -l "$OUT/ports.txt" \
  -silent \
  -title \
  -tech-detect \
  -status-code \
  -server \
  -json \
  -o "$OUT/httpx.jsonl"

touch "$HOST_OUT/urls.txt"

docker exec security-scanner sh -c \
  "jq -r '.url' '$OUT/httpx.jsonl' > '$OUT/urls.txt'"

echo
echo "[6/6] Nuclei CRITICAL..."

touch "$HOST_OUT/nuclei.jsonl"

docker exec security-scanner nuclei \
  -l "$OUT/urls.txt" \
  -t /data/nuclei-templates \
  -severity critical \
  -ni \
  -c 100 \
  -rate-limit 300 \
  -timeout 10 \
  -retries 1 \
  -jsonl \
  -o "$OUT/nuclei.jsonl"

PORTS=$(wc -l < "$HOST_OUT/ports.txt")
HTTP=$(wc -l < "$HOST_OUT/httpx.jsonl")
CRITICAL=$(wc -l < "$HOST_OUT/nuclei.jsonl")

if [ "$CRITICAL" -gt 0 ]; then
    jq -r '
      [
        (.["template-id"] // "unknown"),
        (.info.name // "unknown"),
        (.["matched-at"] // .host // "unknown")
      ]
      | @tsv
    ' "$HOST_OUT/nuclei.jsonl" \
      > "$HOST_OUT/critical-summary.txt"
else
    echo "No critical matches found." \
      > "$HOST_OUT/critical-summary.txt"
fi

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

cat > "$HOST_OUT/summary.env" <<EOF
SCAN_OK=1
SCAN_ID=$SCAN_ID
SCAN_TYPE=FULL
ASN=$ASN
PREFIX_COUNT=$PREFIX_COUNT
PREFIX_IPS=$PREFIX_IPS
TARGETS=$PREFIX_IPS
PORTS=$PORTS
HTTP=$HTTP
CRITICAL=$CRITICAL
RESULT_DIR=$OUT
START=$START_TIME
END=$END_TIME
EOF

echo "COMPLETED" > "$HOST_OUT/status.txt"

echo
echo "========================================"
echo "SCAN_OK"
echo "SCAN_ID=$SCAN_ID"
echo "SCAN_TYPE=FULL"
echo "ASN=$ASN"
echo "PREFIX_COUNT=$PREFIX_COUNT"
echo "PREFIX_IPS=$PREFIX_IPS"
echo "TARGETS=$PREFIX_IPS"
echo "PORTS=$PORTS"
echo "HTTP=$HTTP"
echo "CRITICAL=$CRITICAL"
echo "RESULT_DIR=$OUT"
echo "START=$START_TIME"
echo "END=$END_TIME"
echo "========================================"

echo
echo "CRITICAL_LIST_BEGIN"
cat "$HOST_OUT/critical-summary.txt"
echo "CRITICAL_LIST_END"
