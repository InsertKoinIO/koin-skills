# CLAUDE.md

Contributor notes for working on this repo with Claude Code. End users of the
`koin-migration` plugin do not need to read this — it applies when editing the
skill itself.

## Source of truth

Each skill lives under **`skills/<name>/`** — `SKILL.md`, `evals/evals.json`,
and `references/` (skill-specific files + generated copies of `shared/`):

- `skills/koin-setup/` — set up Koin (new, legacy, or alongside existing DI)
- `skills/koin/` — write Koin code (core, everyday skill)
- `skills/di-migration/` — move definitions from another DI framework, Koin KSP or Koin 3.x
- `skills/koin-diagnose/` — Koin errors and app behavior (static suspects → Kotzilla MCP + SDK)

Plugin manifests live under **`.claude-plugin/`**:

- `plugin.json` — plugin metadata (name, version, description) used by the
  installed plugin
- `marketplace.json` — makes the repo installable via
  `/plugin marketplace add InsertKoinIO/koin-migration` followed by
  `/plugin install koin-migration@koin-migration`. The marketplace `name`
  becomes the `@marketplace` suffix; each `plugins[].name` must match the
  corresponding `plugin.json` `name`.

Content shared by every skill lives under **`shared/`** — one owner file per
topic (`shared/index.md` lists them): `rules.md`, `principles.md`, `gradle.md`,
`entry-points.md`, `scopes.md`, `testing.md`, `koin-annotations.md`,
`koin-safe-dsl.md`, `kotzilla.md`.

**No duplication:** a SKILL.md holds its workflow and the decisions only that
skill owns; every rule, API or version is written once in `shared/` and pointed
to. Links to Koin docs use full `https://insert-koin.io/docs/...` URLs.

Sources are duplication-free: `skills/<name>/` holds only that skill's own
files, `shared/` holds the shared references. Skills link to shared files as
`references/<file>.md` — those paths exist only in the build output.

`./build.sh` assembles complete, self-contained skills in **`build/`**
(git-ignored, never committed): each skill's own files + a copy of every
`shared/*.md` in its `references/`. Three checks make it fail:

- `scripts/check_duplication.py` (before assembling) — a paragraph of 120+
  characters written twice in the sources. Write it once in its owner file and
  point to it.
- a skill file that would shadow a shared one
- `scripts/check_build.py` (after) — every built skill holds all its source
  files and all shared files, byte-identical, every `references/*.md` link
  resolves, and each `.skill` bundle and the plugin zip match `build/plugin/`.

Local drafts go in `draft/` (git-ignored, never shipped).

## After any content change

```bash
./build.sh
```

This validates `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
(including that the plugin name is consistent across both), assembles
`build/plugin/` and builds `build/<skill>-skill.skill` (one per skill) and
`build/koin-migration-plugin.zip`. Everything under `build/` is git-ignored.

## Evals

`./evals.sh` builds the plugin, generates the suite from `skills/*/evals/evals.json`
(`scripts/gen_evals.py`) and runs it with `claude plugin eval`: each case in a
sandboxed Claude Code session that loads only this plugin. Results and the HTML
report go to `eval-results/<timestamp>/` (git-ignored).

```bash
./evals.sh --tag vibe -j 5                          # one group: vibe, compile-safety, migration, kotzilla, principles, coexistence, project
./evals.sh --case 'koin-vibe-*' --keep-temp         # keep the sandbox and its trace.jsonl
ABLATION=with-without ./evals.sh --tag principles   # also run without the plugin, report the gain
MODEL=claude-opus-5-5 MAX_COST_USD=10 ./evals.sh --runs 3
```

**Your own project as a test project** — any git repo works, the sandbox gets a
clean `git archive` copy (no `build/`, agent files `CLAUDE.md`/`AGENTS.md`/`.claude`
stripped):

1. Add it to `evals/projects.json`: `repo` relative to `$KOIN_EVAL_PROJECTS`
   (default `~/workspace`), `ref` (a branch, tag or commit — pin one for stable
   scores), `path` (sub-directory, or `""`)
2. Add a case to the skill's `evals/evals.json` with `"project": "<name>"`,
   `expectations` (one judge check each) and optional `checks`
   (`{"file", "contains" | "absent"}` or `{"answer_absent"}`)
3. `./evals.sh --case '<skill>-<case name>'`

A case whose project isn't on disk is skipped, so the suite runs anywhere.

## Adding a new migration path

1. Create `skills/di-migration/references/<source>-to-koin.md` following the
   structure of the existing references (start with a "Progressive Migration"
   section, then concept mapping, gradle, bindings, qualifiers, retrieval,
   Android/Compose/KMP/testing)
2. Register it in `skills/di-migration/SKILL.md`:
   - Supported Migration Paths table
   - Frontmatter `description` (so the skill triggers on the new framework's name)
3. Add at least one eval case in `skills/di-migration/evals/evals.json`
4. Run `./build.sh`
5. Bump `version` in `.claude-plugin/plugin.json` (MINOR) and add a `CHANGELOG.md` entry

> Note: adding a new migration path **does not** require touching
> `.claude-plugin/marketplace.json` — that file describes the plugin package,
> not its individual skills. Only update `marketplace.json` if the plugin name
> or repo layout changes.

## Releasing

Versioning, tagging, and publishing are scripted. See [RELEASING.md](./RELEASING.md).
Key rule: `.claude-plugin/plugin.json` `version` and the latest `CHANGELOG.md`
heading must agree before running `./release.sh`.

## Koin / skill content guidance

- Safe DSL interface binding: both `single<Impl>().bind<I>()` and
  `single<Impl>().withOptions { bind<I>() }` are valid — do not "normalize" one
  to the other
- Progressive migration is the recommended approach everywhere: create a new
  Koin module alongside the existing DI setup, move definitions feature by
  feature, never rewrite in place
- For Hilt/Dagger sources, always mention the `koin-dagger-bridge` bridge for
  coexistence during migration
- Runtime fixes / debugging / best-practice checks are delegated to the
  **Kotzilla MCP Server** (`https://mcp.kotzilla.io/mcp`) — don't duplicate that
  content into the skill, link to the MCP instead
