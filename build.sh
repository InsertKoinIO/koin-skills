#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SHARED="$ROOT/shared"
PLUGIN_OUT="$ROOT/koin-migration-plugin.zip"

# --- validate sources -------------------------------------------------------

[[ -d "$SHARED" ]]                             || { echo "error: shared/ missing" >&2; exit 1; }
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

# --- sync shared references into every skill -------------------------------
# shared/*.md is the source of truth. Each skill gets a committed copy under
# references/ so it works standalone (plugin install, .skill bundle, skills.sh).

SKILLS=()
for dir in "$ROOT"/skills/*/; do
  [[ -f "$dir/SKILL.md" ]] || continue
  SKILLS+=("$(basename "$dir")")
  mkdir -p "$dir/references"
  for f in "$SHARED"/*.md; do
    name="$(basename "$f")"
    { echo "<!-- GENERATED from shared/$name by build.sh — edit shared/$name, not this copy -->"
      echo
      cat "$f"
    } > "$dir/references/$name"
  done
done
[[ ${#SKILLS[@]} -gt 0 ]] || { echo "error: no skills/*/SKILL.md found" >&2; exit 1; }
echo "synced shared/ into: ${SKILLS[*]}"

# --- build .skill bundles (portable single-skill archives, flat layout) -----

for skill in "${SKILLS[@]}"; do
  src="$ROOT/skills/$skill"
  out="$ROOT/$skill-skill.skill"
  rm -f "$out"
  (cd "$src" && zip -rq "$out" SKILL.md references $([[ -d evals ]] && echo evals) \
     -x "*/.DS_Store" "*.DS_Store")
  echo "built: $out"
done

# --- build plugin .zip (marketplace submission layout) ----------------------

rm -f "$PLUGIN_OUT"
(cd "$ROOT" && zip -rq "$PLUGIN_OUT" \
  .claude-plugin \
  skills \
  README.md \
  LICENSE \
  CHANGELOG.md \
  -x "skills/*/.DS_Store" "*.DS_Store")
echo "built: $PLUGIN_OUT"

echo
echo "--- plugin contents ---"
unzip -l "$PLUGIN_OUT"
