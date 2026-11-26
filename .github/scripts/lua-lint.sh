#!/usr/bin/env bash
# Lint one checked-out tree with glualint.
# Usage: lua-lint.sh <source-dir> <label>
# Prints GitHub annotations, appends a section to $GITHUB_STEP_SUMMARY (if set),
# writes <source-dir>/../lint-<label>.log, exits 1 on any GLua parse error.
set -uo pipefail
src=$1; label=$2
here=$(cd "$(dirname "$0")" && pwd)
glualint=${GLUALINT:-$HOME/glualint/glualint}
log="$(cd "$src/.." && pwd)/lint-${label//\//_}.log"

cd "$src"
# Some files end lines with \r\r\n. LuaJIT/GMod read them fine, but glualint
# reports a false parse error, so fix them in this working copy only.
grep -rlIZ --include='*.lua' $'\r\r' . | xargs -0 -r perl -pi -e 's/\r+\n/\n/g'

"$glualint" --config "$here/../glualint.json" lint --output-format github . 2>&1 \
  | grep '^::' | grep -v "is the same as just" > "$log" || true

errors=$(grep -c '^::error' "$log" || true)
warnings=$(grep -c '^::warning' "$log" || true)

# Annotations: GitHub shows the first 10 of each kind per step.
grep '^::error' "$log" || true
grep '^::warning' "$log" | head -n 10 || true

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Lua lint: \`$label\` @ \`$(git rev-parse --short HEAD 2>/dev/null)\`"
    echo
    echo "| Check | Count |"
    echo "|---|---|"
    echo "| Parse errors (blocking) | ${errors} |"
    echo "| Lint warnings (report only) | ${warnings} |"
    echo
    if [ "$errors" -gt 0 ]; then
      echo "### Parse errors"
      sed -nE 's/^::error file=\.\/([^,]*),line=([0-9]+).*::(.*)/- `\1:\2` \3/p' "$log"
      echo
    fi
    echo "<details><summary>Warnings by type</summary>"
    echo
    echo "| Type | Count |"
    echo "|---|---|"
    sed -nE 's/^::warning.*title="([^"]*)".*/\1/p' "$log" | sort | uniq -c | sort -rn \
      | awk '{c=$1; $1=""; sub(/^ /,""); print "| " $0 " | " c " |"}'
    echo
    echo "</details>"
    echo
  } >> "$GITHUB_STEP_SUMMARY"
fi

echo "lua-lint [$label]: ${errors} parse error(s), ${warnings} warning(s)"
[ "$errors" -eq 0 ]
