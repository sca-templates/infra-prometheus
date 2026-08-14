# Prometheus — Claude Code

This project is shared between agents: the canonical service guide lives in
`AGENTS.md` (imported below) and the Prometheus skills live in
`.claude/skills/` (also registered for opencode via `opencode.jsonc`).

Claude Code priorities:

- Consult `.claude/skills/` first — Claude auto-invokes a skill when a task
  matches its description.
- Use the `codegraph` MCP server (`codegraph_explore`) before grep/read for
  code questions.
- Run `make validate` before finishing any change and report the result.

@AGENTS.md
