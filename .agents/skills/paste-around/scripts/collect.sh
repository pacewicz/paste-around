#!/bin/bash
# collect.sh — paste-around clipboard collector  #2026-08-01 initial
# Polls the X clipboard; every NEW substantial text lands as resp-NN in the
# consult dir. Operator workflow: select-all + copy each engine response in
# the browser — nothing else. Byte-exact capture (no agent-context round-trip).
# Ignores: the prompt itself, tiny copies (<500 B), repeats of already-saved
# content. Exits at <expected-count> files or timeout. Pairs with watch.sh
# (collector creates files, watcher notifies the agent) or replaces it.
#
# Usage: collect.sh <consult-dir> <expected-count> [timeout-minutes=90]
set -euo pipefail

DIR="${1:?usage: collect.sh <consult-dir> <expected-count> [timeout-min]}"
WANT="${2:?expected response count required}"
TIMEOUT_MIN="${3:-90}"
DEADLINE=$(( $(date +%s) + TIMEOUT_MIN*60 ))

clip() { timeout 3 xclip -selection clipboard -o 2>/dev/null || true; }
sum()  { printf '%s' "$1" | md5sum | cut -d' ' -f1; }
toast(){ command -v notify-send >/dev/null && notify-send "paste-around" "$1" || true; }

declare -A SEEN
SEEN[$(sum "$(cat "$DIR/00-prompt.md" 2>/dev/null)")]=prompt
# NOTE: do NOT blanket-blacklist the startup clipboard.  #2026-08-04 baseline-swallow fix
# Operators routinely copy the first engine response BEFORE starting the
# collector; hashing that as "baseline" ignored it forever, and re-copying the
# same text produced the same hash, so it could never be recovered. Substantial
# non-prompt content present at start is now captured below like any response.
STARTCLIP="$(clip)"
# already-saved responses: never overwrite, never re-save same content  #2026-08-01 resume fix
N=0
for f in "$DIR"/resp-*; do
  [[ -f "$f" ]] || continue
  SEEN[$(sum "$(cat "$f")")]=existing
  num=${f##*resp-}; num=${num%%[^0-9]*}
  (( 10#$num > N )) && N=$((10#$num))
done
echo "Collecting: copy each response in the browser (ctrl+a ctrl+c). $WANT expected, ${TIMEOUT_MIN}min timeout."
# startup clipboard: report it so the operator knows whether it counted  #2026-08-04
if [[ -n "$STARTCLIP" && ${#STARTCLIP} -ge 500 && -z "${SEEN[$(sum "$STARTCLIP")]:-}" ]]; then
  echo "  startup clipboard: ${#STARTCLIP} bytes of non-prompt text, capturing as a response."
elif [[ -n "$STARTCLIP" ]]; then
  echo "  startup clipboard: ${#STARTCLIP} bytes, prompt or under 500B, ignored."
fi
while :; do
  C="$(clip)"
  if [[ -n "$C" && ${#C} -ge 500 ]]; then
    H=$(sum "$C")
    if [[ -z "${SEEN[$H]:-}" ]]; then
      SEEN[$H]=saved
      N=$((N+1))
      F="$DIR/resp-$(printf '%02d' "$N")"
      printf '%s' "$C" > "$F"
      echo "$(date +%H:%M:%S) saved $F (${#C} bytes)"
      toast "saved resp-$(printf '%02d' "$N") ($N/$WANT)"
      (( N >= WANT )) && { echo "All $WANT collected."; toast "all $WANT collected — ingest starting"; exit 0; }
    fi
  fi
  (( $(date +%s) > DEADLINE )) && { echo "Timeout: $N/$WANT after ${TIMEOUT_MIN}min."; exit 1; }
  sleep 1
done
