#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
SHARED="$SRC/shared"
SKILLS_OUT="$ROOT/skills"                # generated, committed: the plugin is the repo root
BUILD="$ROOT/build"                      # git-ignored: evals copy, .skill bundles, plugin zip
PLUGIN_DIR="$BUILD/plugin"
PLUGIN_OUT="$BUILD/koin-plugin.zip"

# --- validate sources -------------------------------------------------------

[[ -d "$SHARED" ]]                             || { echo "error: src/shared/ missing" >&2; exit 1; }
[[ -f "$ROOT/.claude-plugin/plugin.json" ]]      || { echo "error: .claude-plugin/plugin.json missing" >&2; exit 1; }
[[ -f "$ROOT/.claude-plugin/marketplace.json" ]] || { echo "error: .claude-plugin/marketplace.json missing" >&2; exit 1; }
[[ -f "$ROOT/LICENSE" ]]                       || { echo "error: LICENSE missing" >&2; exit 1; }
[[ -f "$ROOT/README.md" ]]                     || { echo "error: README.md missing" >&2; exit 1; }

# basic plugin.json sanity check
python3 -c "import json,sys; m=json.load(open('$ROOT/.claude-plugin/plugin.json')); [sys.exit(f'plugin.json missing field: {f}') for f in ('name','version','description','license','repository') if f not in m]"

# marketplace.json sanity + consistency with plugin.json
python3 -c "
import json, sys
plug = json.load(open('$ROOT/.claude-plugin/plugin.json'))
mkt  = json.load(open('$ROOT/.claude-plugin/marketplace.json'))
for f in ('name', 'owner', 'plugins'):
    if f not in mkt: sys.exit(f'marketplace.json missing field: {f}')
if not isinstance(mkt['plugins'], list) or not mkt['plugins']:
    sys.exit('marketplace.json: plugins[] must be a non-empty array')
names = [p.get('name') for p in mkt['plugins']]
if plug['name'] not in names:
    sys.exit(f\"marketplace.json: no plugin entry matches plugin.json name '{plug['name']}' (found {names})\")
for p in mkt['plugins']:
    if 'source' not in p:
        sys.exit(f\"marketplace.json: plugin {p.get('name')!r} missing 'source'\")
"

# --- source duplication check ----------------------------------------------

python3 "$ROOT/scripts/check_duplication.py" "$ROOT"

# --- assemble complete skills in skills/ ------------------------------------
# Sources stay duplication-free: src/skills/<name>/ holds only the skill's own
# files, src/shared/ the shared references. skills/ gets complete,
# self-contained skills (own files + shared references), committed so the repo
# root installs as is.

rm -rf "$SKILLS_OUT" "$BUILD"
mkdir -p "$SKILLS_OUT"

SKILLS=()
for dir in "$SRC"/skills/*/; do
  [[ -f "$dir/SKILL.md" ]] || continue
  skill="$(basename "$dir")"
  SKILLS+=("$skill")
  out="$SKILLS_OUT/$skill"
  mkdir -p "$out/references"
  (cd "$dir" && find . -type f ! -name ".DS_Store" -exec sh -c 'mkdir -p "$0/$(dirname "$1")" && cp "$1" "$0/$1"' "$out" {} \;)
  for f in "$SHARED"/*.md; do
    name="$(basename "$f")"
    [[ -e "$dir/references/$name" ]] && { echo "error: src/skills/$skill/references/$name shadows src/shared/$name" >&2; exit 1; }
    cp "$f" "$out/references/$name"
  done
done
[[ ${#SKILLS[@]} -gt 0 ]] || { echo "error: no src/skills/*/SKILL.md found" >&2; exit 1; }
echo "assembled in skills/: ${SKILLS[*]}"

# --- copy the plugin to build/plugin (evals write their suite into it) ------

mkdir -p "$PLUGIN_DIR/.claude-plugin"
cp "$ROOT/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/icon.png" "$PLUGIN_DIR/.claude-plugin/"
cp -R "$SKILLS_OUT" "$PLUGIN_DIR/skills"
cp "$ROOT/README.md" "$ROOT/LICENSE" "$ROOT/CHANGELOG.md" "$PLUGIN_DIR/"

# --- check that every references/*.md link resolves -------------------------

missing=0
for skill in "${SKILLS[@]}"; do
  out="$SKILLS_OUT/$skill"
  for ref in $(grep -rhoE 'references/[a-z0-9-]+\.md' "$out" | sort -u); do
    [[ -f "$out/$ref" ]] || { echo "error: $skill links to $ref, not found" >&2; missing=1; }
  done
done
[[ $missing -eq 0 ]] || exit 1

# --- build .skill bundles (portable single-skill archives, flat layout) -----

for skill in "${SKILLS[@]}"; do
  bundle="$BUILD/$skill-skill.skill"
  (cd "$PLUGIN_DIR/skills/$skill" && zip -rq "$bundle" .)
  echo "built: build/$skill-skill.skill"
done

# --- build plugin .zip (marketplace submission layout) ----------------------

(cd "$PLUGIN_DIR" && zip -rq "$PLUGIN_OUT" .claude-plugin skills README.md LICENSE CHANGELOG.md)
echo "built: build/koin-plugin.zip"

# --- post-build check: everything copied, bundles complete -----------------

python3 "$ROOT/scripts/check_build.py" "$ROOT"
