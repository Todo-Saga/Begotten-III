# Begotten III — notes for AI agents (Todo-Saga fork)

This file lives only on the fork's `main`. Upstream is DETrooper/Begotten-III.
**PR branches for upstream must start from upstream `main`, never from this
fork's `main`**, or this file and `.github/` will leak into the upstream PR.

## Lua lint CI (`.github/workflows/lua-lint.yml`)

GLua syntax check (any parse error fails the run) + glualint warnings
(report only) + **"New vs upstream base"**: warnings the commit adds on lines it
changed, versus its merge-base with DETrooper `main`. That last table is the
one that matters for a PR. Config: `.github/glualint.json`; logic:
`.github/scripts/lua-lint.sh` (whole tree), `lua-lint-ref.sh` (tree + new-vs-base),
`lua-lint-new.py` (the diff).

**Branches**
- Never push to DETrooper. `perf/framework-schema-optimizations` is the head of
  upstream PR #156, so pushing it updates the upstream PR; only do that when
  the user says the PR is ready.
- `verify/pr156`, `verify/pr157`: mirrors of the current local PR tips, safe to
  push at any time; the hourly job lints them. Update with
  `git push saga <sha>:refs/heads/verify/pr15x` (force is fine on `verify/*`).

**Runs automatically**
- on every push / PR to this fork that touches `.lua`;
- hourly at :17 UTC on **every branch tip on the fork** not linted before, so
  PR branches are checked without carrying the workflow. A new tip is linted
  within about an hour of being pushed.

**Run it on demand** (`ref` = branch, tag or SHA on the fork):
- GitHub MCP: `actions_run_trigger` with `method: run_workflow`,
  `owner: Todo-Saga`, `repo: Begotten-III`, `workflow_id: lua-lint.yml`,
  `ref: main`, `inputs: {"ref": "<branch>"}`
  (all branches: `inputs: {"all_branches": "true", "force": "true"}`).
- gh CLI: `gh workflow run lua-lint.yml -R Todo-Saga/Begotten-III -f ref=<branch>`
  then `gh run watch -R Todo-Saga/Begotten-III`.
- Actions tab → Lua lint → Run workflow.

**Read results**
- Run conclusion: success = no parse errors.
- Job summary: parse errors, counts by warning type, then the "New in <branch>"
  table. Artifact `glualint-log` / `glualint-logs-all-branches` (folder
  `lint-logs/`): `lint-<branch>.log` (all warnings, one `::warning file=…,line=…`
  per line) and `new-<branch>.txt` (the new-vs-base table).
- MCP: `actions_list` `list_workflow_runs` (resource_id `lua-lint.yml`),
  then `get_job_logs` with `return_content: true`.

**Run it locally** (Linux):
```sh
curl -fsSL -o /tmp/g.zip https://github.com/FPtje/GLuaFixer/releases/download/1.29.0/glualint-1.29.0-x86_64-linux.zip
unzip -o -q /tmp/g.zip -d ~/glualint
cp -r . /tmp/lintcopy   # the script rewrites \r\r\n line endings in place
GLUALINT=~/glualint/glualint .github/scripts/lua-lint.sh /tmp/lintcopy local
```
New-vs-base for one commit of a full clone (needs `upstream/main` fetched):
`GLUALINT=~/glualint/glualint .github/scripts/lua-lint-ref.sh . <sha> <label>`

**Known false positives / baseline** (upstream code, not your bug)
- ~770 warnings on `main` (unused variables, empty blocks, 20 "Bad self").
  Style checks are off; `addons/DEACTIVATED` and `deactivatedplugins` are skipped.
- `\r\r\n` line endings break glualint's parser (e.g. `cw_mounted*`); the
  script normalises them. LuaJIT/GMod parse those files fine.
- `frame:AddText` "function is broken" and SWEP `self.Weapon` notes are filtered.
- Plain `luac`/LuaJIT cannot be the syntax check: the code uses GLua syntax
  (`!`, `!=`, `&&`, `//`).
