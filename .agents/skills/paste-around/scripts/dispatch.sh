#!/bin/bash
# dispatch.sh — paste-around tier-1 helper  #2026-08-01 initial
# Loads 00-prompt.md into the X clipboard and opens the chosen engine portals
# as browser tabs. The human does ctrl+v + send per tab — deliberately manual
# (ToS / play-nice: no automation of consumer chat UIs).
#
# Usage: dispatch.sh <consult-dir> <engine> [engine...]
# Engines: perplexity gemini chatgpt grok deepseek qwen
set -euo pipefail

declare -A URL=(
  [perplexity]="https://www.perplexity.ai/"
  [gemini]="https://gemini.google.com/app"
  [chatgpt]="https://chatgpt.com/"
  [grok]="https://grok.com/"
  [deepseek]="https://chat.deepseek.com/"
  [qwen]="https://chat.qwen.ai/"
)
declare -A HINT=(
  [perplexity]="enable Deep Research mode"
  [gemini]="enable Deep Research (browser product)"
  [chatgpt]="enable Deep Research mode"
  [grok]="enable DeepSearch, NOT standard mode"
  [deepseek]="check web-search toggle is ON"
  [qwen]="check web-search toggle is ON"
)

# Operator roster override: ~/.config/paste-around/engines.conf  #2026-08-02
# One engine per line:   name|url|hint
# If the file exists it REPLACES the built-in roster above (curate additions
# and removals in one place; built-ins are only the no-config fallback).
CONF="${PASTE_AROUND_ENGINES:-$HOME/.config/paste-around/engines.conf}"
if [[ -f "$CONF" ]]; then
  unset URL HINT; declare -A URL HINT
  while IFS='|' read -r n u h; do
    [[ -z "$n" || "$n" == \#* ]] && continue
    URL[$n]="$u"; HINT[$n]="${h:-no hint}"
  done < "$CONF"
fi

DIR="${1:?usage: dispatch.sh <consult-dir> <engine> [engine...]}"
shift
PROMPT="$DIR/00-prompt.md"
[[ -s "$PROMPT" ]] || { echo "ERROR: $PROMPT missing or empty" >&2; exit 1; }
(( $# >= 1 )) || { echo "ERROR: no engines given (${!URL[*]})" >&2; exit 1; }

for e in "$@"; do
  [[ -n "${URL[$e]:-}" ]] || { echo "ERROR: unknown engine '$e' (${!URL[*]})" >&2; exit 1; }
done

xclip -selection clipboard < "$PROMPT"
echo "Prompt in clipboard ($(wc -c < "$PROMPT") bytes)."
xdg-open "$DIR" >/dev/null 2>&1 &   # consult dir in file manager = save target  #2026-08-01
echo
for e in "$@"; do
  xdg-open "${URL[$e]}" >/dev/null 2>&1 &
  printf "  %-11s %s  <- %s\n" "$e" "${URL[$e]}" "${HINT[$e]}"
  sleep 2
done
echo
echo "Per tab: ctrl+v, confirm mode/toggle per hint above, send."
echo "Save each response into: $DIR (any filename, any extension)"
