# Pull Request

## Summary

<!-- One or two lines: what this PR changes and why. -->

## Changes

<!-- List the notes/files touched. -->

## Checklist

- [ ] I have read [CONTRIBUTING.md](CONTRIBUTING.md).
- [ ] Content is in English.
- [ ] `.env.example` is updated when new variables are added.
- [ ] No secrets or tokens are committed (`.env` stays gitignored).
- [ ] `make validate` passes locally.
- [ ] `promtool check config prometheus.yml` passes.
- [ ] `docker compose -f compose.yml config --quiet` passes.
- [ ] `shellcheck scripts/*.sh` passes.
- [ ] `npx --yes markdownlint-cli2 README.md AGENTS.md CLAUDE.md .github/PULL_REQUEST_TEMPLATE.md .github/CONTRIBUTING.md docs/handbook/README.md .claude/skills/**/SKILL.md .opencode/command/*.md` passes.
- [ ] `README.md` is updated when the stack, ports or commands change.
