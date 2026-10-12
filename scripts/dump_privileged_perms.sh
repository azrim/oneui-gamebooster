#!/usr/bin/env bash
# Dump the list of permissions whose protectionLevel includes 'privileged'
# from a connected Samsung device, into data/privileged-permissions.txt.
#
# Usage: scripts/dump_privileged_perms.sh [serial]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$HERE/data/privileged-permissions.txt"
ADB=(adb)
[ -n "${1:-}" ] && ADB=(adb -s "$1")

tmp="$(mktemp)"
"${ADB[@]}" shell "pm list permissions -f" > "$tmp"

python3 - "$tmp" "$OUT" <<'PY'
import re, sys
src, out = sys.argv[1], sys.argv[2]
priv = set(); cur = None
for line in open(src, encoding='utf-8', errors='replace'):
    m = re.match(r'\+ permission:(\S+)', line)
    if m: cur = m.group(1)
    m = re.match(r'\s+protectionLevel:(.*)', line)
    if m and cur and 'privileged' in m.group(1):
        priv.add(cur)
with open(out, 'w') as f:
    f.write("# Permissions whose protectionLevel includes 'privileged' (dumped from a Samsung One UI device).\n")
    f.write("# Regenerate with: scripts/dump_privileged_perms.sh\n")
    for p in sorted(priv):
        f.write(p + "\n")
print(f"wrote {out} ({len(priv)} entries)")
PY
rm -f "$tmp"
