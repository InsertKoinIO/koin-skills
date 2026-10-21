#!/usr/bin/env python3
"""Post-build check: every built skill is complete and matches its sources.

For each src/skills/<name>/ source:
  - skills/<name>/ holds every source file, byte-identical
  - skills/<name>/references/ holds every src/shared/*.md, byte-identical
  - every `references/<file>.md` link in the built skill resolves
  - build/plugin/skills/<name>/ is identical to skills/<name>/
  - build/<name>-skill.skill contains exactly the built skill's files
  - build/koin-plugin.zip contains the built skill
  - SKILL.md frontmatter: name == folder name, description 1–1024 characters
"""
import sys, zipfile, filecmp, re
from pathlib import Path

root = Path(sys.argv[1])
build, shared, sources = root / "build", root / "src" / "shared", root / "src" / "skills"
generated, plugin = root / "skills", root / "build" / "plugin"
errors = []

def files(d):
    return {p.relative_to(d).as_posix() for p in d.rglob("*") if p.is_file() and p.name != ".DS_Store"}

plugin_zip = zipfile.ZipFile(build / "koin-plugin.zip")
plugin_entries = set(plugin_zip.namelist())
shared_files = sorted(p.name for p in shared.glob("*.md"))

for src in sorted(d for d in sources.iterdir() if (d / "SKILL.md").is_file()):
    name, out = src.name, generated / src.name
    expected = files(src) | {f"references/{f}" for f in shared_files}
    built = files(out)
    for f in sorted(expected - built):
        errors.append(f"{name}: missing {f}")
    for f in sorted(built - expected):
        errors.append(f"{name}: unexpected {f}")
    for f in files(src):
        if (out / f).exists() and not filecmp.cmp(src / f, out / f, shallow=False):
            errors.append(f"{name}: {f} differs from source")
    for f in shared_files:
        b = out / "references" / f
        if b.exists() and not filecmp.cmp(shared / f, b, shallow=False):
            errors.append(f"{name}: references/{f} differs from src/shared/{f}")
    for f in built:
        if f.endswith(".md"):
            for ref in set(re.findall(r"references/[a-z0-9-]+\.md", (out / f).read_text())):
                if not (out / ref).exists():
                    errors.append(f"{name}: {f} links to {ref}, not found")
    fm = re.match(r"^---\n(.*?)\n---\n", (out / "SKILL.md").read_text(), re.S)
    if not fm:
        errors.append(f"{name}: SKILL.md has no frontmatter")
    else:
        n = re.search(r"^name:\s*(\S+)", fm.group(1), re.M)
        d = re.search(r"^description:\s*>?\s*\n?(.*)", fm.group(1), re.S | re.M)
        if not n or n.group(1) != name:
            errors.append(f"{name}: frontmatter name must equal the folder name")
        desc = re.sub(r"\s+", " ", d.group(1)).strip() if d else ""
        if not desc or len(desc) > 1024:
            errors.append(f"{name}: description must be 1–1024 characters (is {len(desc)})")
    copy = plugin / "skills" / name
    if files(copy) != built or any(not filecmp.cmp(out / f, copy / f, shallow=False) for f in built):
        errors.append(f"{name}: build/plugin/skills/{name} differs from skills/{name}")
    bundle = build / f"{name}-skill.skill"
    if not bundle.exists():
        errors.append(f"{name}: bundle {bundle.name} missing")
    else:
        entries = {e for e in zipfile.ZipFile(bundle).namelist() if not e.endswith("/")}
        if entries != built:
            errors.append(f"{name}: bundle differs from skills/ ({sorted(entries ^ built)[:5]})")
    zipped = {e[len(f"skills/{name}/"):] for e in plugin_entries if e.startswith(f"skills/{name}/") and not e.endswith("/")}
    if zipped != built:
        errors.append(f"{name}: plugin zip differs from skills/ ({sorted(zipped ^ built)[:5]})")
    print(f"  {name}: {len(built)} files ({len(files(src))} own + {len(shared_files)} shared)")

if errors:
    print("\n".join("error: " + e for e in errors), file=sys.stderr)
    sys.exit(1)
print("post-build check: OK")
