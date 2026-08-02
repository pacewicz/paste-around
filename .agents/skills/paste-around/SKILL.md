---
name: paste-around
description: Consult external frontier models (Perplexity, Gemini, Grok, ChatGPT, DeepSeek, Qwen...) on a research question via manual browser paste — no API keys, uses the operator's existing subscriptions. The skill composes ONE self-contained, privacy-scrubbed research prompt, the operator pastes it into 2-4 deep-research engine UIs and saves responses into a consult directory, then the skill ingests, fact-checks, and synthesizes them into a convergence verdict. Use whenever the user says "paste around", "ask other models", "ask the room", "get second opinions from other AIs", "consult gemini/grok/perplexity", wants prior-art research before building something, or drops model-response files into a consult directory for ingestion. Also use the ingest half alone when the user says "results are in" or points at a directory of pasted model responses.
---

# paste-around — manual multi-model consult loop

Two halves, two invocations. **Compose**: build the prompt, hand it to the operator,
exit. **Ingest**: when responses land, verify and synthesize. You cannot pause
mid-turn waiting for a human to visit four websites — never try; the exit between
halves is the design (claudeblattman proved this "two-invocation" shape; a
single-invocation wait is architecturally impossible).

Detect which half applies from the consult directory state: only `00-prompt.md`
present → compose already done, remind operator what to paste where. Response
files present → ingest. No directory yet → compose.

## Why this exists

Deep-research engines (Perplexity, Gemini, Grok, ChatGPT, DeepSeek, Qwen) have
different search indexes; consulting several catches what any one misses. APIs for
these modes are expensive or unavailable — but the operator already pays for the
browser UIs. The human is the transport layer. That step is deliberately manual;
everything around it (compose, verify, synthesize) is yours.

Local agents count as engines too: when composing, also consider spawning a
web-capable research subagent (whatever your harness offers — pin a cheap
model for grunt search) and/or a second local CLI agent from a different
vendor (e.g. from Claude Code: `codex exec --skip-git-repo-check --sandbox
read-only -c tools.web_search=true "<question>"`; from Codex: `claude -p
"<question>"`) — in the first live run, the locals found the best prior art
that all five consumer engines missed. Their results enter the same synthesis
as equal rows.

## Phase 1 — Compose

1. Create `~/consults/<YYYY-MM-DD>-<slug>/`.
2. Write the prompt to `00-prompt.md`. **The file is 100% payload** — no markdown
   header, no meta-comments, nothing that isn't meant for the target engine. The
   operator selects all and copies; anything extra pollutes every consultation.
   Paste instructions go in your terminal output, never in the file.
3. **Scrub**: no hostnames, IPs, usernames, employer names, internal codenames.
   These prompts go to public systems. Generalize ("several Linux machines on a
   home LAN"), don't redact visibly.

### Prompt template

Open with the identification/probe block, verbatim in spirit:

> Before anything else, begin your response with a short identification block:
> your model name and version, the product and mode you are running in (e.g.
> "Gemini Deep Research"), whether live web search/browsing is ENABLED or
> DISABLED in this session, and today's date. If web access is disabled, say so
> and stop — do not answer from memory. Then answer.

Why: filenames lie (operator saves as `1`, `2`, `deepsek`) — the self-ID block is
the reliable engine label at ingest. The search probe + stop-clause is live-fire
verified: a search-disabled engine produced a 98-byte honest stop instead of 3KB
of confabulation.

Then five blocks:

1. **Context** — one paragraph: who, setup, environment. Fully self-contained;
   the engine has zero prior context and performs worse when it must infer any.
2. **Numbered pains** — concrete observable symptoms, never pre-baked solutions.
3. **Requirements** — bullets; hard constraints explicit (self-hosted, LAN-first,
   no cloud). Add negative constraints ("do NOT research X; Y is settled") —
   consumer engines over-deliver into tangents without them.
4. **Known primitives** — raw signals/facts already available. Prevents engines
   re-suggesting discarded options.
5. **The ask** — numbered explicit questions. Forces comparable, structured
   answers instead of essays.

Then, if prior rounds or local research already established a baseline:

> Known baseline — do not spend words rediscovering these: <list>. Report only
> what goes BEYOND these.

Close with the output contract:

> Output contract:
> - Number your answer sections to match my questions.
> - Every concrete claim ends with [Source Name](URL); if you cannot find a
>   source, write "no source found" — do not invent one.
> - Tag anything you are unsure of with [unverified].
> - Separate facts from your own inference.
> - Keep it under 2000 words. No preamble restating my workflow back to me.

Why the contract: forced `[Source](URL)` syntax makes claims machine-verifiable
in Phase 3; word cap kills padding (one uncapped response was 22KB with ~4KB of
signal); "no source found" reduces fabricated citations. Constrain via task
design, not meta-prompts — "don't hallucinate" is ignored, structure is not.

### Hand-off output (terminal, not file)

Tell the operator: file path, which engines to use and why, and per-engine hints.
Engine selection is by **index diversity**, not count — returns diminish after
2-3 engines because indexes overlap, not because models are similar:

| Engine | Marginal value | Hint |
|---|---|---|
| Perplexity Deep Research | citation-forward baseline, broad web | enable Deep Research; exports clean markdown |
| Gemini Deep Research | Google index, YouTube, Scholar | enable Deep Research (browser product, not CLI) |
| Grok DeepSearch | X-freshness — hobby tools announced there first; skip if question has no recency/social component | enable DeepSearch, NOT standard mode |
| ChatGPT Deep Research | depth/reasoning; skip if an OpenAI brain (codex) is already in the loop | enable Deep Research mode |
| DeepSeek | different corpus incl. Chinese ecosystem | enable web search — check the toggle |
| Qwen | different corpus; lower citation reliability observed in early runs — verification phase covers it | enable web search — check the toggle |

Always remind: **check the web-search/deep-research toggle is actually ON** —
a memory-only answer from a search-capable engine is worse than no answer, and
the engine's own "ENABLED" self-report has been observed to be false.

Response return path, tell the operator both:
- Save/export each response into the consult dir. Any filename, any or no
  extension — ingest reads everything and identifies engines by self-ID block.
- Short answers may be pasted directly into chat; you will file them yourself
  tagged `source: pasted-via-chat`. Full deep-research reports must be files:
  pasted text has to be regenerated token-by-token to reach disk (drift +
  double cost on 10k-word reports); files are byte-exact.

### Tier-1 helpers (OPTIONAL — currently Linux/X11 only)

The skill's core loop is platform-agnostic: compose, manual paste, save files,
ingest, verify, synthesize all work anywhere. The helper scripts below only
remove friction, and currently assume X11 (`xclip`, `xdg-open`). On Windows,
macOS, or headless/SSH sessions: skip them, hand the operator the prompt path
and consult dir as text, and let them save responses manually — nothing else
changes.

`scripts/dispatch.sh <consult-dir> <engine...>` — loads the prompt into the
clipboard and opens the chosen portals as browser tabs with per-engine hints.
Operator's remaining work: ctrl+v + send per tab, save responses. Run it for
the operator when a graphical session is available; on SSH-only sessions skip
it and hand over paths as text.

`scripts/collect.sh <consult-dir> <expected-count> [timeout-min]` — run as a
background task after dispatch (if your harness lacks background tasks with
completion notifications, tell the operator to run it in a terminal and come
back when it exits); polls the clipboard and saves every new
substantial copy as `resp-NN` in the consult dir, byte-exact. Operator's whole
return path becomes: copy each response in the browser (response copy-button
preferred over ctrl+a — less UI chrome), done. Ignores the prompt, <500-byte
copies, and repeats; desktop toast per save. Warn the operator not to copy
unrelated large text while it runs. Exits 0 when all expected responses are in.

`scripts/watch.sh <consult-dir> <expected-count> [timeout-min]` — same
completion contract but watches for files appearing by any route (manual
save/export, drag-drop) instead of the clipboard. Use collect.sh when the
operator copies responses, watch.sh when they save files; either one's
background-task completion notification is your cue to start ingest without
the operator having to say "results are in". Count only engines actually
dispatched; timeout default 90 min (deep-research runs take 2-45 min each).
The send step stays human on purpose — automating consumer chat UIs violates
their ToS and risks bans on paid accounts.

With the watcher running you have not exited, but the no-polling rule stands:
the watcher does the waiting, you do nothing until its notification.

## Phase 2 — Ingest

Trigger: operator says results are in, or you find new files in the consult dir.

1. Read **every** file in the dir except `00-prompt*` and `SYNTHESIS*`.
   Extension-agnostic, name-agnostic. Identify each engine from its self-ID
   block first, filename only as fallback; note search-enabled status and
   response date (a wrong date is a memory-contamination flag).
2. Partial returns are normal — some engines fail or get skipped. Synthesize
   what arrived; note absentees in the synthesis.
3. If a response is a stop-notice (search disabled), record it as such — that is
   the contract working, not a failure to retry silently.

## Phase 3 — Verify

Mandatory, regardless of engine self-reports or how plausible claims look.
Observed failure mode: engine claims "search ENABLED", returns wrong date, and
fabricates all three of its top recommendations — including citation laundering
(a real-looking arXiv ID pointing at an unrelated paper).

What counts as load-bearing: anything a ranking, verdict, or synthesis
conclusion rests on. If an engine puts a tool in its top-3, that tool gets
verified no matter what form the citation takes — repo, blog post, product
page, paper. The observed miss: an agent verified every GitHub repo and doc
link but skipped a blog-cited tool that anchored an engine's #1 ranking; the
tool was fabricated and the fake ranking entered the synthesis as legitimate
disagreement.

Methods:
- Repos: `curl -s -o /dev/null -w "%{http_code}" https://api.github.com/repos/<owner>/<name>` (pause ~1s between calls — play nice)
- URLs (blogs, product pages, docs): HTTP status via curl -L
- Papers: fetch title, compare against the claimed topic — ID existing ≠ claim true
- Unlinked tool names (engine names a tool but gives no URL): try
  `https://api.github.com/search/repositories?q=<name>` before writing it off
  as unverifiable — verified-real beats unverified in ranking weight

Record every check in the verification log with result. A claim that fails
verification kills the finding but stays in the log — the hallucination pattern
per engine is itself data for future engine selection.

## Phase 4 — Synthesize

Write `SYNTHESIS.md` in the consult dir. Raw inputs are never edited. Schema:

```markdown
---
date: YYYY-MM-DD
topic: <topic>
type: synthesis
sources: <count>
---

# <Topic> — Synthesis

## Source Reports
- [<engine>, <mode/search status>] <path>   # locals (subagents, CLI agents) listed identically
- [Original prompt] <path>

## Headline Findings
## Agreements            # cite which sources; [Consensus: N/M] tags welcome
## Contradictions        # who said what; no forced winner unless evidence one-sided;
                         # weigh down self-serving placements (engine recommending itself)
## Gaps & Open Questions
## Unique Per-Source Insights
### From <each source, including locals and poisoned ones — a fabrication note is an insight>
## Verification log      # every check: claim → method → result
```

All sources get uniform treatment — local agents are engines, same rows, same
verification, same unique-contribution accounting. When you summarize the
synthesis in chat, the per-source table must include every source; do not slice
locals off.

Finally, fold the verdict back into the working plan/conversation — the
synthesis is an input to the current task, not a report for its own sake.

## Iteration

If the verdict hasn't converged or the operator fixes a fault (e.g. search was
off), refine `00-prompt.md` (add the new baseline anchor so round 2 spends
tokens on marginal finds only) and rename superseded responses aside with a
reason suffix (`grok.r1-nowebsearch`) — never delete; search-off/on pairs are
comparison data. Convergence across independent engines is the trust signal;
divergence means an under-specified prompt or a genuinely contested topic.
