# paste-around

**Consult every frontier model you already pay for — without a single API key.**

An agent skill (Claude Code, Codex CLI, Gemini CLI, OpenCode — anything that
reads the [Agent Skills](https://agentskills.io) `SKILL.md` format) implementing
the *manual multi-model consult loop*: your agent composes ONE self-contained,
privacy-scrubbed research prompt; you paste it into 2–4 deep-research chatbot
UIs (Perplexity, Gemini, Grok, ChatGPT, DeepSeek, Qwen…); a clipboard collector
captures each answer byte-exact; the agent then **fact-checks every
load-bearing claim** and synthesizes a convergence verdict.

The human is the transport layer. That's the feature: consumer deep-research
subscriptions cost a fraction of the equivalent API calls, and nothing gets
automated against the portals' terms of service.

```
agent composes prompt ──> clipboard + browser tabs open
                                │
                     you: ctrl+v, send, copy answer   (per portal)
                                │
              collector saves each copy byte-exact ──> consult dir
                                │
        agent ingests ─> verifies claims ─> SYNTHESIS.md ─> your plan
```

## Why the verification step is the point

In this skill's first production runs, cross-checking caught one engine
fabricating **all three** of its top-ranked tool recommendations — including
*citation laundering*: a real-looking arXiv ID pointing at an unrelated paper.
Another engine's honest "web search is disabled, stopping" (the prompt's
stop-clause working as designed) produced a 98-byte file instead of 3 KB of
confabulation. Convergence across independently-indexed engines is the trust
signal; every repo, paper, and blog post a ranking rests on gets curl-verified
before it reaches the synthesis.

## Install

Clone once, link everywhere:

```bash
git clone https://github.com/pacewicz/paste-around
cd paste-around && ./install.sh          # symlinks into ~/.claude/skills, ~/.codex/skills, ~/.gemini/skills
                                         # ./install.sh --copy if symlinks don't suit you
```

Claude Code plugin route instead:

```
/plugin marketplace add pacewicz/paste-around
/plugin install paste-around@paste-around-marketplace
```

Project-scoped agents (OpenCode, Gemini workspace mode) discover
`.agents/skills/` in a checked-out repo directly — no install step.

The canonical skill lives at `.agents/skills/paste-around/`; the top-level
`skills/` symlink exists for the Claude Code plugin format.

## Use

Say `paste around <question>` (or "ask other models", "get second opinions").
The skill:

1. **Compose** — creates `~/consults/<date>-<slug>/00-prompt.md`: pure payload
   (safe to select-all), self-ID + web-search-probe opener with a stop-clause,
   five structured blocks, an output contract that makes claims
   machine-verifiable (`[Source](URL)` or "no source found").
2. **Dispatch** (X11) — `scripts/dispatch.sh` loads the prompt into your
   clipboard, opens the portal tabs and the consult folder, prints per-engine
   mode hints. `scripts/collect.sh` then watches the clipboard: copy each
   response in the browser and it lands as a byte-exact file, desktop toast
   per catch.
3. **Ingest** — extension- and filename-agnostic; engines are identified by
   their self-ID block, not what you named the file.
4. **Verify** — GitHub API for repos, curl for URLs, title-match for papers.
   Anything a ranking rests on gets checked regardless of citation form.
5. **Synthesize** — `SYNTHESIS.md`: agreements with `[Consensus: N/M]` tags,
   contradictions without forced winners, unique insight per source, gaps,
   and a full verification log. Local agents (subagents, `codex exec`) enter
   the same table as equal sources.

Engine selection is by **index diversity** (Grok = X-freshness, Gemini =
Google/YouTube, DeepSeek = different corpus), not by count — returns diminish
after 2–3 engines because the indexes overlap, not because the models agree.

## Requirements

- Claude Code with skills support
- Linux/X11 for the dispatch/collect helpers (`xclip`, `xdg-open`);
  the compose/ingest/verify/synthesize core is platform-agnostic
- Consumer accounts on whichever deep-research portals you like

## Prior art

Surveyed before building (10 sources — including this skill's own loop asking
five engines about itself): nothing ships the full manual-relay + verification
+ synthesis loop. Closest is the "paste-loop" in
[chrisblattman/claudeblattman](https://github.com/chrisblattman/claudeblattman)
(MIT) — the two-invocation pattern and the synthesis schema here derive from
it; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). API-driven councils
(Karpathy's llm-council and its ports) solve a different problem — they need
API keys; this deliberately doesn't.

## License

MIT
