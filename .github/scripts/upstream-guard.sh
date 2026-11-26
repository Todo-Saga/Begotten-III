#!/usr/bin/env bash
# Fail if a branch meant for upstream would carry fork-only or AI-tool content.
# Usage: upstream-guard.sh <repo-dir> <ref> [label]
# Needs refs/remotes/upstream/main in <repo-dir>. Checks everything the ref adds
# on top of its merge-base with upstream main:
#   - fork-only files: AGENTS.md, CLAUDE.md, .claude/, .github/
#   - added lines, commit messages and author/committer identities containing
#     claude / anthropic / co-authored-by
# Also warns (does not fail) on "#<number>" in commit messages, because a fork
# commit that names an upstream PR/issue number shows up on its public timeline.
set -uo pipefail
repo=$1 ref=$2 label=${3:-$2}
words='claude|anthropic|co-authored-by'
fail=0
out() { echo "$*"; [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "$*" >>"$GITHUB_STEP_SUMMARY"; }
bad() { out "- ✗ **$label**: $*"; fail=1; }

case "$label" in claude/*|*/claude/*) bad "branch name contains 'claude'";; esac

base=$(git -C "$repo" merge-base "$ref" refs/remotes/upstream/main 2>/dev/null) || {
  out "- ? **$label**: no merge-base with upstream main, skipped"; exit 0; }

files=$(git -C "$repo" diff --name-only "$base" "$ref" |
  grep -iE '(^|/)(agents|claude)\.md$|(^|/)\.claude/|^\.github/' || true)
[ -n "$files" ] && bad "fork-only files: $(echo $files | tr ' ' ',')"

lines=$(git -C "$repo" diff "$base" "$ref" | grep -E '^\+' | grep -v '^+++' |
  grep -icE "$words" || true)
[ "${lines:-0}" -gt 0 ] && bad "$lines added line(s) mention $words"

msgs=$(git -C "$repo" log --format='%h %an <%ae> %cn <%ce>%n%B' "$base..$ref" |
  grep -iE "$words" | head -3 || true)
[ -n "$msgs" ] && bad "commit message/identity: $(echo "$msgs" | tr '\n' ' ' | cut -c1-200)"

refs=$(git -C "$repo" log --format='%h %s%n%b' "$base..$ref" | grep -E '(^|[^&[:alnum:]])#[0-9]+' | head -3 || true)
[ -n "$refs" ] && out "- ⚠ **$label**: commit message names #<number> (links to upstream timeline): $(echo "$refs" | head -1 | cut -c1-120)"

[ $fail = 0 ] && out "- ✓ **$label** ($(git -C "$repo" rev-list --count "$base..$ref") commits)"
exit $fail
