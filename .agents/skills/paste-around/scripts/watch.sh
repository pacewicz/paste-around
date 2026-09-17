#!/bin/bash
# watch.sh — paste-around tier-1 collector  #2026-08-01 initial
# Blocks until <count> response files exist in the consult dir (anything that
# is not 00-prompt* / SYNTHESIS* / *.r*-*), then exits 0. Poll-based (10s) —
# no inotify-tools dependency. Meant to be run as a background Bash task so
# the agent gets a completion notification and starts ingest.
#
# Operator-driven stop  #2026-08-26: <expected-count> is a guessed upper bound
# (esp. with the 1min multi-model portal, the real count isn't known up front),
# so also drop a marker file the operator can delete the moment THEY are done
# pasting responses in, regardless of count. Deleting it is the authoritative
# "results are in" signal — checked every poll, wins over count and timeout.
#
# Usage: watch.sh <consult-dir> <expected-count> [timeout-minutes=90]
set -euo pipefail

DIR="${1:?usage: watch.sh <consult-dir> <expected-count> [timeout-min]}"
WANT="${2:?expected response count required}"
TIMEOUT_MIN="${3:-90}"
DEADLINE=$(( $(date +%s) + TIMEOUT_MIN*60 ))
MARKER="$DIR/DELETE-THIS-FILE-WHEN-DONE-PASTING"

echo "Still collecting responses — delete this file when you're done pasting them all in, and I'll pick up from there." > "$MARKER"

count() {
  find "$DIR" -maxdepth 1 -type f \
    ! -name '00-prompt*' ! -name 'SYNTHESIS*' ! -name '*.r[0-9]-*' \
    ! -name "$(basename "$MARKER")" \
    -newer "$DIR/00-prompt.md" 2>/dev/null | wc -l
}

echo "Watching $DIR for $WANT response file(s), timeout ${TIMEOUT_MIN}min."
echo "Marker: $MARKER — delete it anytime to signal done regardless of count."
LAST=-1
while :; do
  [[ -f "$MARKER" ]] || { echo "$(date +%H:%M:%S) marker deleted by operator — ready for ingest."; exit 0; }
  N=$(count)
  (( N != LAST )) && { echo "$(date +%H:%M:%S) responses: $N/$WANT"; LAST=$N; }
  (( N >= WANT )) && { echo "All $WANT in — ready for ingest."; rm -f "$MARKER"; exit 0; }
  (( $(date +%s) > DEADLINE )) && { echo "Timeout: $N/$WANT after ${TIMEOUT_MIN}min."; rm -f "$MARKER"; exit 1; }
  sleep 10
done
