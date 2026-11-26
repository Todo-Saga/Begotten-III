#!/usr/bin/env python3
"""Report glualint warnings a branch adds on lines it touched.

Usage: lua-lint-new.py <repo> <base-sha> <tip-sha> <base.log> <tip.log> <label>
Logs are glualint --output-format github output for the changed files only.
A warning counts as new when (file, type, message) occurs more often at tip
than at base AND it sits on a line changed by base..tip.
Writes a markdown section to $GITHUB_STEP_SUMMARY (if set) and stdout.
"""
import collections, os, re, subprocess, sys

repo, base, tip, blog, tlog, label = sys.argv[1:7]
pat = re.compile(r'^::(\w+) file=\./([^,]*),line=(\d+),.*?title="([^"]*)"::(.*)$')

def load(path):
    rows = []
    if os.path.exists(path):
        for line in open(path, encoding='utf-8', errors='replace'):
            m = pat.match(line.strip())
            if m:
                rows.append((m[1], m[2], int(m[3]), m[4], m[5]))
    return rows

b, t = load(blog), load(tlog)
diff = subprocess.run(['git', '-C', repo, 'diff', '-U0', base, tip, '--', '*.lua'],
                      capture_output=True, text=True, errors='replace').stdout
touched, cur = collections.defaultdict(set), None
for line in diff.splitlines():
    if line.startswith('+++ '):
        cur = line[6:] if line.startswith('+++ b/') else None
    m = re.match(r'@@ -\S+ \+(\d+)(?:,(\d+))? @@', line)
    if m and cur:
        start, n = int(m[1]), int(m[2] if m[2] is not None else 1)
        touched[cur].update(range(start, start + n))

bc = collections.Counter((r[1], r[3], r[4]) for r in b)
tc = collections.Counter((r[1], r[3], r[4]) for r in t)
new = [r for r in t if tc[(r[1], r[3], r[4])] > bc.get((r[1], r[3], r[4]), 0)
       and r[2] in touched[r[1]]]
new.sort(key=lambda r: (r[0] != 'error', r[3], r[1], r[2]))

out = [f"### New in `{label}` vs upstream base `{base[:8]}`", ""]
if not new:
    out.append("No new warnings on changed lines.")
else:
    out += ["| Kind | Type | Location | Message |", "|---|---|---|---|"]
    for r in new[:100]:
        out.append(f"| {r[0]} | {r[3]} | `{r[1]}:{r[2]}` | {r[4].replace('|', '/')} |")
    if len(new) > 100:
        out.append(f"\n…and {len(new) - 100} more (see log artifact).")
    for r in new[:10]:  # inline annotations
        print(f"::{r[0]} file={r[1]},line={r[2]},title=New: {r[3]}::{r[4]}")
text = "\n".join(out) + "\n\n"
print(text)
if os.environ.get('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as f:
        f.write(text)
