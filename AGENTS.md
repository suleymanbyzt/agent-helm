# Contributing to agent-helm (agent instructions)

This repository IS the framework — it must practice what it preaches.

- `core/AGENTS.md` is the product. Every line must earn its place: if
  removing a line would not cause an agent to make mistakes, remove it.
- Keep it small: `core/AGENTS.md` under ~150 lines, each SKILL.md under
  ~100 lines. Push detail into skills, never into the constitution.
- Skills use only portable frontmatter fields (`name`, `description`) so
  they work in Claude Code, Codex, and any Agent Skills-compatible tool.
  No vendor-specific syntax inside shared skills.
- All repository content (docs, skills, templates, comments, CLI output)
  is in English.
- Test installer changes by running them against a scratch directory
  before claiming they work.
