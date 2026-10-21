# CLAUDE.md

Contributor notes for working on this repo with Claude Code. End users of the
`koin` plugin do not need to read this — it applies when editing the skills
themselves.

## Source of truth

**Never modify `skills/` directly — edit `src/`, then run `./build.sh`.** `skills/`
at the repo root is generated and committed: it is the installed plugin
(marketplace `"source": "./"`, `claude --plugin-dir .`, the Anthropic directory
tracking `main`), so it can't be git-ignored. CI fails when it differs from a
fresh build; `.gitattributes` collapses it in PR diffs.

Each skill's sources live under **`src/skills/<name>/`** — `SKILL.md` and
skill-specific `references/`:

- `src/skills/koin-setup/` — set up Koin (new, legacy, or alongside existing DI)
- `src/skills/koin/` — write Koin code (core, everyday skill)
- `src/skills/di-migration/` — move definitions from another DI framework, Koin KSP or Koin 3.x
- `src/skills/koin-diagnose/` — Koin errors and app behavior (static suspects → Kotzilla MCP + SDK)

Plugin manifests live under **`.claude-plugin/`**:

- `plugin.json` — plugin metadata (name, version, description) used by the
  installed plugin
- `marketplace.json` — makes the repo installable via
  `/plugin marketplace add InsertKoinIO/koin-skills` followed by
  `/plugin install koin@koin-skills`. The marketplace `name`
  becomes the `@marketplace` suffix; each `plugins[].name` must match the
  corresponding `plugin.json` `name`.

Content shared by every skill lives under **`src/shared/`** — one owner file per
topic (`src/shared/index.md` lists them): `rules.md`, `principles.md`, `gradle.md`,
`entry-points.md`, `scopes.md`, `testing.md`, `koin-annotations.md`,
`koin-compiler-plugin-dsl.md`, `kotzilla.md`.

**No duplication:** a SKILL.md holds its workflow and the decisions only that
skill owns; every rule, API or version is written once in `src/shared/` and pointed
to. Links to Koin docs use full `https://insert-koin.io/docs/...` URLs.

Sources are duplication-free: `src/skills/<name>/` holds only that skill's own
files, `src/shared/` holds the shared references. Skills link to shared files as
`references/<file>.md` — those paths exist only in the generated `skills/`.

`./build.sh` regenerates complete, self-contained skills in **`skills/`**
(committed): each skill's own files + a copy of every `src/shared/*.md` in its
`references/`. Three checks make it fail:

- `scripts/check_duplication.py` (before assembling) — a paragraph of 120+
  characters written twice in the sources. Write it once in its owner file and
  point to it.
- a skill file that would shadow a shared one
- `scripts/check_build.py` (after) — every generated skill holds all its source
  files and all shared files, byte-identical, every `references/*.md` link
  resolves, and `build/plugin/`, each `.skill` bundle and the plugin zip match `skills/`.

Local drafts go in `draft/` (git-ignored, never shipped).

## After any content change

```bash
./build.sh
```

This validates `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
(including that the plugin name is consistent across both), regenerates
`skills/`, copies the plugin to `build/plugin/` (the evals write their suite
there, never into the repo) and builds `build/<skill>-skill.skill` (one per
skill) and `build/koin-plugin.zip`. Commit `src/` and `skills/` together;
everything under `build/` is git-ignored.

## Evals

The eval suite (cases, harness, project snapshots) lives in a separate private
repo, `kotzilla-io/koin-skills-evals`, checked out next to this one. It builds
this plugin with `./build.sh` and runs it with `claude plugin eval`. Its
`CLAUDE.md` covers running, adding cases and adding projects.

## Adding a new migration path

1. Create `src/skills/di-migration/references/<source>-to-koin.md` following the
   structure of the existing references (start with a "Progressive Migration"
   section, then concept mapping, gradle, bindings, qualifiers, retrieval,
   Android/Compose/KMP/testing)
2. Register it in `src/skills/di-migration/SKILL.md`:
   - Supported Migration Paths table
   - Frontmatter `description` (so the skill triggers on the new framework's name)
3. Add at least one eval case in the evals repo (`cases/di-migration.json`)
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

- Compiler Plugin DSL interface binding: both `single<Impl>().bind<I>()` and
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
