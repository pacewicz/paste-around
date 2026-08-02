# Repo instructions (all agents)

This repo ships one agent skill: `.agents/skills/paste-around/SKILL.md`
(the manual multi-model consult loop) plus its bash helpers in
`scripts/` next to it. The top-level `skills/` is a compatibility symlink
for the Claude Code plugin format — edit only under `.agents/`.

When working on this repo:
- The SKILL.md is the product. Keep it agent-agnostic: no harness-specific
  tool names in instructions; capabilities phrased conditionally ("if your
  harness supports background tasks...").
- Shell scripts are plain bash + xclip/xdg-open (X11). No new dependencies
  without a strong reason.
- Every behavioral claim in SKILL.md's engine table carries a dated marker
  (#YYYY-MM-DD) — preserve them; they are observations, not opinions.
