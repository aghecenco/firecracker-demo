#!/bin/bash -e

SB_ID="${1:-0}" # Default to sb_id=0

SNAPSHOT="snapshots/fc$SB_ID.bin"
MEM_FILE="snapshots/fc$SB_ID.mem"
API_SOCKET="/tmp/firecracker-sb${SB_ID}.sock"
CURL=(curl --silent --show-error --header Content-Type:application/json --unix-socket "${API_SOCKET}" --write-out "HTTP %{http_code}")

logfile="$PWD/output/fc-sb${SB_ID}-resumed-log"
metricsfile="/dev/null"

touch $logfile

curl_put() {
    local URL_PATH="$1"
    local OUTPUT RC
    OUTPUT="$("${CURL[@]}" -X PUT --data @- "http://localhost/${URL_PATH#/}" 2>&1)"
    RC="$?"
    if [ "$RC" -ne 0 ]; then
        echo "Error: curl PUT ${URL_PATH} failed with exit code $RC, output:"
        echo "$OUTPUT"
        return 1
    fi
    # Error if output doesn't end with "HTTP 2xx"
    if [[ "$OUTPUT" != *HTTP\ 2[0-9][0-9] ]]; then
        echo "Error: curl PUT ${URL_PATH} failed with non-2xx HTTP status code, output:"
        echo "$OUTPUT"
        return 1
    fi
}

# Start Firecracker API server
rm -f "$API_SOCKET"

./firecracker_snapshotting_wip --api-sock "$API_SOCKET" --id "${SB_ID}" &

sleep 0.015s

# Wait for API server to start
while [ ! -e "$API_SOCKET" ]; do
    echo "FC $SB_ID still not ready..."
    sleep 0.01s
done

curl_put '/logger' <<EOF
{
  "log_fifo": "$logfile",
  "metrics_fifo": "$metricsfile",
  "level": "Info",
  "show_level": false,
  "show_log_origin": false
}
EOF

curl_put '/snapshot/load' <<EOF
{
  "snapshot_path": "$SNAPSHOT",
  "mem_file_path": "$MEM_FILE"
}
EOF
