#!/bin/bash
# collect.sh — paste-around clipboard collector  #2026-08-01 initial
# Polls the X clipboard; every NEW substantial text lands as resp-NN in the
# consult dir. Operator workflow: select-all + copy each engine response in
# the browser — nothing else. Byte-exact capture (no agent-context round-trip).
# Ignores: the prompt itself, noise copies, repeats of already-saved content.
# Exits at <expected-count> files or timeout. Pairs with watch.sh (collector
# creates files, watcher notifies the agent) or replaces it.
#
# Capture rule is content-aware, not a flat byte floor  #2026-08-26: two
# failure modes had to be reconciled. (a) A 500B floor silently dropped a real
# ~214B Grok search-disabled stop-notice as "noise" — but a stop-notice is a
# legitimate, recordable response (the honest-refusal case the prompt's
# stop-clause is designed to elicit). (b) A flat low floor (an earlier 50B fix)
# over-captures: across a 90-min window the operator copies URLs, paths, and
# snippets for unrelated reasons, and every such >50B copy became a spurious
# resp-NN that polluted ingest. Resolution: accept any copy >=500B (a full
# response), OR a shorter copy that carries the identification block this
# skill's OWN prompt mandates every answer open with ("...whether live web
# search/browsing is ENABLED or DISABLED..."). Random clipboard noise lacks
# that signature; stop-notices always have it. Keys off the prompt contract,
# so it stays correct as long as the prompt keeps requiring the ID block.
#
# Operator-driven stop  #2026-08-26: <expected-count> is a guessed upper bound
# (esp. with the 1min multi-model portal, the real count isn't known up front),
# so also drop a marker file the operator can delete the moment THEY are done
# pasting responses in, regardless of count. Deleting it is the authoritative
# "results are in" signal — checked every poll, wins over count and timeout.
#
# Usage: collect.sh <consult-dir> <expected-count> [timeout-minutes=90]
set -euo pipefail

DIR="${1:?usage: collect.sh <consult-dir> <expected-count> [timeout-min]}"
WANT="${2:?expected response count required}"
TIMEOUT_MIN="${3:-90}"
DEADLINE=$(( $(date +%s) + TIMEOUT_MIN*60 ))
MARKER="$DIR/DELETE-THIS-FILE-WHEN-DONE-PASTING"

echo "Still collecting responses — delete this file when you're done pasting them all in, and I'll pick up from there." > "$MARKER"

clip() { timeout 3 xclip -selection clipboard -o 2>/dev/null || true; }
sum()  { printf '%s' "$1" | md5sum | cut -d' ' -f1; }
toast(){ command -v notify-send >/dev/null && notify-send "paste-around" "$1" || true; }
# is_response: real engine output worth saving? Full responses pass on size;
# short ones pass only if they carry the mandated search-status ID line, so a
# stop-notice counts but a stray URL/path/snippet copy does not.  #2026-08-26
is_response() {
  local s="$1"
  (( ${#s} >= 500 )) && return 0
  (( ${#s} >= 40 )) \
    && printf '%s' "$s" | grep -qiE 'search|browsing|web access' \
    && printf '%s' "$s" | grep -qiE 'enabled|disabled' \
    && return 0
  return 1
}

declare -A SEEN
# Blacklist EVERY prompt file, not just 00-prompt.md  #2026-09-10 multi-prompt fix:
# an interrogation consult ships several numbered prompts (00-prompt-01-*.md ...)
# that get loaded into the clipboard one at a time, so a single-file hash let
# prompts 02+ land as spurious resp-NN.
for p in "$DIR"/00-prompt*; do
  [[ -f "$p" ]] && SEEN[$(sum "$(cat "$p")")]=prompt
done
# NOTE: do NOT blanket-blacklist the startup clipboard.  #2026-08-04 baseline-swallow fix
# Operators routinely copy the first engine response BEFORE starting the
# collector; hashing that as "baseline" ignored it forever, and re-copying the
# same text produced the same hash, so it could never be recovered. Substantial
# non-prompt content present at start is now captured below like any response.
STARTCLIP="$(clip)"
# already-saved responses: never overwrite, never re-save same content  #2026-08-01 resume fix
N=0
SAVED=0   # this run's saves; separate from filename counter  #2026-08-18 resume double-bug fix
for f in "$DIR"/resp-*; do
  [[ -f "$f" ]] || continue
  SEEN[$(sum "$(cat "$f")")]=existing
  num=${f##*resp-}; num=${num%%[^0-9]*}
  # named responses (resp-local-codex.md) yield an empty num — 10# on empty is a
  # syntax error, and counting them into N made WANT trip instantly  #2026-08-18
  [[ -n "$num" ]] || continue
  (( 10#$num > N )) && N=$((10#$num))
done
echo "Collecting: copy each response in the browser (ctrl+a ctrl+c). $WANT expected, ${TIMEOUT_MIN}min timeout."
# startup clipboard: report it so the operator knows whether it counted  #2026-08-04
if [[ -n "$STARTCLIP" ]] && is_response "$STARTCLIP" && [[ -z "${SEEN[$(sum "$STARTCLIP")]:-}" ]]; then
  echo "  startup clipboard: ${#STARTCLIP} bytes of non-prompt text, capturing as a response."
elif [[ -n "$STARTCLIP" ]]; then
  echo "  startup clipboard: ${#STARTCLIP} bytes, prompt or non-response noise, ignored."
fi
echo "Marker: $MARKER — delete it anytime to signal done regardless of count."
while :; do
  [[ -f "$MARKER" ]] || { echo "$(date +%H:%M:%S) marker deleted by operator — ready for ingest."; toast "marker deleted — ingest starting"; exit 0; }
  C="$(clip)"
  if [[ -n "$C" ]] && is_response "$C"; then
    H=$(sum "$C")
    if [[ -z "${SEEN[$H]:-}" ]]; then
      SEEN[$H]=saved
      N=$((N+1)); SAVED=$((SAVED+1))
      F="$DIR/resp-$(printf '%02d' "$N")"
      printf '%s' "$C" > "$F"
      echo "$(date +%H:%M:%S) saved $F (${#C} bytes)"
      toast "saved resp-$(printf '%02d' "$N") ($SAVED/$WANT)"
      (( SAVED >= WANT )) && { echo "All $WANT collected."; toast "all $WANT collected — ingest starting"; rm -f "$MARKER"; exit 0; }
    fi
  fi
  (( $(date +%s) > DEADLINE )) && { echo "Timeout: $SAVED/$WANT after ${TIMEOUT_MIN}min."; rm -f "$MARKER"; exit 1; }
  sleep 1
done
