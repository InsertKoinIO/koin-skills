#!/usr/bin/env bash
# Build the plugin, generate its eval suite, run it with `claude plugin eval`.
# Extra args go to `claude plugin eval`, e.g.:
#   ./evals.sh --tag koin
#   ./evals.sh --case koin-refuse-service-locator-in-usecase --keep-temp
#   MODEL=claude-opus-5-5 ./evals.sh --runs 3
#   ABLATION=with-without ./evals.sh --tag principles
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MODEL="${MODEL:-claude-sonnet-5-5}"
MAX_COST_USD="${MAX_COST_USD:-5}"
# with-without adds a run without the plugin and reports the difference
ABLATION="${ABLATION:-none}"
# skills read their references/ from here, outside the sandbox workspace
PLUGIN="$ROOT/build/plugin"
# outside build/, which build.sh wipes
RESULTS="$ROOT/eval-results/$(date +%Y-%m-%dT%H-%M-%S)"

"$ROOT/build.sh"
python3 "$ROOT/scripts/gen_evals.py" "$ROOT"

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
