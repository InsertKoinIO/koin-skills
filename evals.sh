#!/usr/bin/env bash
# Build the plugin, generate its eval suite, run it with `claude plugin eval`.
# Extra args go to `claude plugin eval`, e.g.:
#   ./evals.sh --tag koin
#   ./evals.sh --case koin-refuse-service-locator-in-usecase --keep-temp
#   MODEL=claude-opus-5-5 ./evals.sh --runs 3
#   ABLATION=with-without ./evals.sh --tag principles
#   SETUP=both ./evals.sh       # koin (default), google (Google's Android skills only), both
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MODEL="${MODEL:-claude-sonnet-5-5}"
MAX_COST_USD="${MAX_COST_USD:-5}"
# with-without adds a run without the plugin and reports the difference
ABLATION="${ABLATION:-none}"
SETUP="${SETUP:-koin}"
GOOGLE_SKILLS="${KOIN_EVAL_PROJECTS:-$HOME/workspace}/apps/google-android/skills"
# outside build/, which build.sh wipes
RESULTS="$ROOT/eval-results/$(date +%Y-%m-%dT%H-%M-%S)-${SETUP:-koin}"

"$ROOT/build.sh"
case "$SETUP" in
  koin) PLUGIN="$ROOT/build/plugin"; GEN_ARGS=() ;;
  both) PLUGIN="$ROOT/build/plugin"; GEN_ARGS=(--with android-skills) ;;
  google)
    PLUGIN="$ROOT/build/google-plugin"
    rm -rf "$PLUGIN" && mkdir -p "$PLUGIN"
    git -C "$GOOGLE_SKILLS" archive HEAD | tar -x -C "$PLUGIN"
    GEN_ARGS=(--plugin "$PLUGIN") ;;
  *) echo "error: SETUP must be koin, google or both" >&2; exit 1 ;;
esac
python3 "$ROOT/scripts/gen_evals.py" "$ROOT" ${GEN_ARGS[@]+"${GEN_ARGS[@]}"}

claude plugin eval "$PLUGIN" \
  --model "$MODEL" \
  --max-cost-usd "$MAX_COST_USD" \
  --ablation "$ABLATION" \
  --trust-plugin \
  --no-publish \
  --output-dir "$RESULTS" \
  --report "$RESULTS/report.html" \
  --scaffold \
  --allow-tools "Read(/$PLUGIN/**)" "Glob(/$PLUGIN/**)" "Grep(/$PLUGIN/**)" Write Edit \
  "$@"
