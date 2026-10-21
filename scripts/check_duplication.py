#!/usr/bin/env python3
"""Source duplication check: the same paragraph must not be written twice.

Scans src/shared/*.md and src/skills/**/*.md (sources only — never skills/ or build/). A paragraph
of 120+ characters that appears in two places is an error: write it once in its
owner file and point to it. One-line pointers to an owner file are allowed.
"""
import sys, re, collections
from pathlib import Path

root = Path(sys.argv[1])
sources = sorted(list((root / "src" / "shared").glob("*.md")) + list((root / "src" / "skills").rglob("*.md")))
POINTER = re.compile(r"^(>?\s*\**[^`]{0,40}\**\s*[—:-]?\s*)?(Add Koin per|See |Same mapping as|AFTER:|Gradle convention plugins:|Koin side|`references/|Constructor and function parameters \(`T`)")

seen = collections.defaultdict(list)
for f in sources:
    text = re.sub(r"^---\n.*?\n---\n", "", f.read_text(), flags=re.S)
    for para in re.split(r"\n\s*\n", text):
        p = re.sub(r"\s+", " ", para).strip()
        if len(p) < 120 or POINTER.match(p) or p.startswith("|"):
            continue
        seen[p].append(f.relative_to(root).as_posix())

dups = {p: fs for p, fs in seen.items() if len(fs) > 1}
for p, fs in dups.items():
    print(f"error: duplicated paragraph in {', '.join(fs)}:\n    {p[:110]}…", file=sys.stderr)
if dups:
    sys.exit(1)
print(f"duplication check: OK ({len(sources)} source files)")
