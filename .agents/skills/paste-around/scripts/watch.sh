#!/bin/bash
# watch.sh — paste-around tier-1 collector  #2026-08-01 initial
# Blocks until <count> response files exist in the consult dir (anything that
# is not 00-prompt* / SYNTHESIS* / *.r*-*), then exits 0. Poll-based (10s) —
# no inotify-tools dependency. Meant to be run as a background Bash task so
# the agent gets a completion notification and starts ingest.
#
# Usage: watch.sh <consult-dir> <expected-count> [timeout-minutes=90]
set -euo pipefail

DIR="${1:?usage: watch.sh <consult-dir> <expected-count> [timeout-min]}"
WANT="${2:?expected response count required}"
TIMEOUT_MIN="${3:-90}"
DEADLINE=$(( $(date +%s) + TIMEOUT_MIN*60 ))

count() {
  find "$DIR" -maxdepth 1 -type f \
    ! -name '00-prompt*' ! -name 'SYNTHESIS*' ! -name '*.r[0-9]-*' \
    -newer "$DIR/00-prompt.md" 2>/dev/null | wc -l
}

echo "Watching $DIR for $WANT response file(s), timeout ${TIMEOUT_MIN}min."
LAST=-1
while :; do
  N=$(count)
  (( N != LAST )) && { echo "$(date +%H:%M:%S) responses: $N/$WANT"; LAST=$N; }
  (( N >= WANT )) && { echo "All $WANT in — ready for ingest."; exit 0; }
  (( $(date +%s) > DEADLINE )) && { echo "Timeout: $N/$WANT after ${TIMEOUT_MIN}min."; exit 1; }
  sleep 10
done
