# paste-around

**Consult the frontier models you pay for. No API keys.**

An agent skill (Claude Code, Codex CLI, Gemini CLI, OpenCode, or other tools
reading the [Agent Skills](https://agentskills.io) `SKILL.md` format) implementing
the *manual multi-model consult loop*. Your agent writes one self-contained,
privacy-scrubbed research prompt. You paste it into 2–4 deep-research chatbot
UIs (Perplexity, Gemini, Grok, ChatGPT, DeepSeek, Qwen…). A clipboard collector
saves each answer byte-exact. The agent **fact-checks the load-bearing claims**
and writes a convergence verdict.

You carry the payload between tabs. Consumer deep-research subscriptions cost a
fraction of the equivalent API calls, and leaving the browser to you keeps the
loop inside the portals' terms of service.

```
agent composes prompt ──> clipboard + browser tabs open
                                │
                     you: ctrl+v, send, copy answer   (per portal)
                                │
              collector saves each copy byte-exact ──> consult dir
                                │
        agent ingests ─> verifies claims ─> SYNTHESIS.md ─> your plan
```

## Verification

In the first production runs, cross-checking caught one engine fabricating its
three top-ranked tool recommendations, including a laundered citation: a
real-looking arXiv ID pointing at an unrelated paper. Another engine hit the
prompt's stop-clause and answered "web search is disabled, stopping", a 98-byte
file in place of 3 KB of confabulation. Agreement across engines with different
indexes counts once you check the sources, so the skill
curl-checks each repo, paper and post a ranking depends on before it reaches
the synthesis.

## Install

Clone the repo, link the skill:

```bash
git clone https://github.com/pacewicz/paste-around
cd paste-around && ./install.sh          # symlinks into ~/.claude/skills, ~/.codex/skills, ~/.gemini/skills
                                         # ./install.sh --copy if symlinks don't suit you
```

Claude Code plugin instead:

```
/plugin marketplace add pacewicz/paste-around
/plugin install paste-around@paste-around-marketplace
```

Project-scoped agents (OpenCode, Gemini workspace mode) read `.agents/skills/`
from a checked-out repo, with no install step.

The canonical skill path is `.agents/skills/paste-around/`. The top-level
`skills/` symlink serves the Claude Code plugin format.

## Use

Say `paste around <question>` ("ask other models" and "get second opinions"
work too). Five steps:

1. **Compose**: the skill creates `~/consults/<date>-<slug>/00-prompt.md`
   containing prompt text with no wrapper, so you can select-all. Inside: a
   self-ID and web-search-probe opener with a stop-clause, five structured
   blocks, an output contract requiring `[Source](URL)` or "no source found".
2. **Dispatch** (X11): `scripts/dispatch.sh` loads the prompt into your
   clipboard, opens the portal tabs and the consult folder, prints per-engine
   mode hints. Run `scripts/collect.sh` alongside it. Copy a response in the
   browser and the script writes it byte-exact, one desktop toast per catch.
3. **Ingest**: extension- and filename-agnostic. The skill reads each file's
   self-ID block to identify the engine and ignores what you named the file.
4. **Verify**: GitHub API for repos, curl for URLs, title-match for papers. The
   skill checks each citation a ranking depends on, whatever form it arrives in.
5. **Synthesize**: `SYNTHESIS.md` carries agreements tagged `[Consensus: N/M]`,
   contradictions without a forced winner, unique insight per source, gaps, and
   the verification log. Local agents (subagents, `codex exec`) enter the same
   table as equal sources.

Pick engines for **index diversity** (Grok for X freshness, Gemini for Google
and YouTube, DeepSeek for a different corpus). Past 2–3 engines the indexes
overlap and the extra answers repeat what you have.

## Requirements

- An agent that reads `SKILL.md` (Claude Code, Codex CLI, Gemini CLI, OpenCode…)
- Consumer accounts on the deep-research portals you want to use
- The core loop is OS-independent. The optional dispatch and collect helpers
  target Linux/X11 (`xclip`, `xdg-open`); on Windows or macOS, save responses
  into the consult dir by hand. Ports welcome, and `pbcopy`/`pbpaste` plus
  `Get-Clipboard` keep them small

## Prior art

I surveyed 10 sources before building, including a run of this loop asking five
engines about itself, and found adjacent projects but none shipping the full
manual-relay, verification and synthesis loop. The closest is the "paste-loop" in
[chrisblattman/claudeblattman](https://github.com/chrisblattman/claudeblattman)
(MIT); the two-invocation pattern and the synthesis schema here derive from it,
see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). API-driven councils
(Karpathy's llm-council and its ports) target a workflow built on API keys.
paste-around runs without them.

## License

MIT
