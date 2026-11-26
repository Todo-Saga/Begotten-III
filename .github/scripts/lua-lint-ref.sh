#!/usr/bin/env bash
# Lint one commit of a full clone, then list warnings it adds versus upstream.
# Usage: lua-lint-ref.sh <repo-dir> <sha> <label>
# Needs refs/remotes/upstream/main in <repo-dir> for the "new warnings" part.
# Exits 1 on any GLua parse error in the whole tree.
set -uo pipefail
repo=$(cd "$1" && pwd); sha=$2; label=$3
here=$(cd "$(dirname "$0")" && pwd)
glualint=${GLUALINT:-$HOME/glualint/glualint}
work=$(mktemp -d); safe=${label//\//_}

git -C "$repo" worktree add -q --detach "$work/tree" "$sha"
"$here/lua-lint.sh" "$work/tree" "$label"; rc=$?
mkdir -p "$repo/../lint-logs"; cp "$work"/lint-*.log "$repo/../lint-logs/" 2>/dev/null

base=$(git -C "$repo" merge-base "$sha" refs/remotes/upstream/main 2>/dev/null || true)
if [ -n "$base" ] && [ "$base" != "$sha" ]; then
  git -C "$repo" diff --name-only --diff-filter=AM "$base" "$sha" -- '*.lua' \
    | grep -vi deactivated > "$work/files" || true
  if [ -s "$work/files" ]; then
    for side in base tip; do
      ref=$base; [ $side = tip ] && ref=$sha
      while IFS= read -r f; do
        git -C "$repo" cat-file -e "$ref:$f" 2>/dev/null || continue
        mkdir -p "$work/$side/$(dirname "$f")"
        git -C "$repo" show "$ref:$f" | perl -pe 's/\r+\n/\n/g' > "$work/$side/$f"
      done < "$work/files"
      if [ -d "$work/$side" ]; then
        (cd "$work/$side" && "$glualint" --config "$here/../glualint.json" lint \
          --output-format github . 2>&1 | grep '^::' | grep -v "is the same as just" \
          > "$work/$side.log" || true)
      fi
    done
    python3 "$here/lua-lint-new.py" "$repo" "$base" "$sha" "$work/base.log" "$work/tip.log" "$label" \
      | tee "$repo/../lint-logs/new-$safe.txt"
  fi
fi
git -C "$repo" worktree remove --force "$work/tree"; rm -rf "$work"
exit $rc
