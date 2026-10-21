#!/usr/bin/env bash
# Publish a GitHub release from the current tag (or a newly created one),
# uploading the .skill bundles and the plugin .zip as release assets.
#
# Usage:
#   ./release.sh                  # use version from .claude-plugin/plugin.json
#   ./release.sh 1.2.0            # override version
#   ./release.sh --draft          # create as draft
#   ./release.sh 1.2.0 --draft    # both
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# --- parse args -------------------------------------------------------------

DRAFT=""
VERSION=""
for arg in "$@"; do
  case "$arg" in
    --draft) DRAFT="--draft" ;;
    -*)      echo "unknown flag: $arg" >&2; exit 2 ;;
    *)       VERSION="$arg" ;;
  esac
done

# --- prerequisites ----------------------------------------------------------

command -v gh >/dev/null    || { echo "error: gh CLI not installed (https://cli.github.com)" >&2; exit 1; }
command -v jq >/dev/null    || { echo "error: jq not installed" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "error: run 'gh auth login' first" >&2; exit 1; }

# --- resolve version --------------------------------------------------------

MANIFEST_VERSION="$(jq -r .version .claude-plugin/plugin.json)"
VERSION="${VERSION:-$MANIFEST_VERSION}"
TAG="v$VERSION"

if [[ "$VERSION" != "$MANIFEST_VERSION" ]]; then
  echo "error: requested version ($VERSION) does not match plugin.json ($MANIFEST_VERSION)" >&2
  echo "       bump plugin.json first, or pass the matching version" >&2
  exit 1
fi

# --- working tree must be clean ---------------------------------------------

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is dirty — commit or stash before releasing" >&2
  git status --short >&2
  exit 1
fi

# --- build ------------------------------------------------------------------

./build.sh >/dev/null
if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: ./build.sh changed skills/ — commit the generated skills before releasing" >&2
  git status --short >&2
  exit 1
fi
SKILLS=("$ROOT"/build/*-skill.skill)
PLUGIN="$ROOT/build/koin-plugin.zip"
[[ -f "${SKILLS[0]}" ]] || { echo "error: no .skill bundles built" >&2; exit 1; }
[[ -f "$PLUGIN" ]] || { echo "error: $PLUGIN not built" >&2; exit 1; }

# --- tag --------------------------------------------------------------------

if git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
  echo "tag $TAG already exists locally — reusing"
else
  echo "creating tag $TAG"
  git tag -a "$TAG" -m "$TAG"
fi

if ! git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  echo "pushing tag $TAG to origin"
  git push origin "$TAG"
fi

# --- release notes ----------------------------------------------------------

NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT

if [[ -f CHANGELOG.md ]] && grep -q "^## \[$VERSION\]" CHANGELOG.md; then
  awk -v v="$VERSION" '
    $0 ~ "^## \\["v"\\]" { on=1; next }
    on && /^## \[/       { exit }
    on                   { print }
  ' CHANGELOG.md > "$NOTES_FILE"
else
  echo "Release $TAG" > "$NOTES_FILE"
fi

# --- release ----------------------------------------------------------------

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "release $TAG already exists — refreshing notes + assets"
  gh release edit "$TAG" --notes-file "$NOTES_FILE"
  gh release upload "$TAG" "${SKILLS[@]}" "$PLUGIN" --clobber
  # If the release is in draft (e.g. orphaned by a previous tag delete), publish it
  if [[ -z "$DRAFT" ]] && [[ "$(gh release view "$TAG" --json isDraft -q .isDraft)" == "true" ]]; then
    echo "release was in draft — publishing"
    gh release edit "$TAG" --draft=false
  fi
else
  echo "creating release $TAG"
  gh release create "$TAG" "${SKILLS[@]}" "$PLUGIN" \
    --title "$TAG" \
    --notes-file "$NOTES_FILE" \
    $DRAFT
fi

echo
echo "done: $(gh release view "$TAG" --json url -q .url)"
