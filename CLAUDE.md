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
`entry-points.md`, `scopes.md`, `koin-annotations.md`, `koin-safe-dsl.md`,
`kotzilla.md`.

**No duplication:** a SKILL.md holds its workflow and the decisions only that
skill owns; every rule, API or version is written once in `shared/` and pointed
to. Links to Koin docs use full `https://insert-koin.io/docs/...` URLs.

`./build.sh` copies each `shared/*.md` into every `skills/*/references/` with a
"GENERATED" header. **Edit `shared/`, never the copies**, then run `./build.sh`
and commit the refreshed copies (the plugin installs straight from the repo, so
the copies must be committed).

There are **no root-level mirrors** of the skill files — each `.skill` bundle is
zipped directly from `skills/<name>/` into a flat layout. If you see a
stray `SKILL.md` or `references/` at the repo root, it's accidental — delete it.

Local drafts go in `draft/` (git-ignored, never shipped).

## After any content change

```bash
./build.sh
```

This validates `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
(including that the plugin name is consistent across both), then rebuilds
`di-migration-skill.skill` and `koin-migration-plugin.zip`. Both artifacts are
git-ignored — do not commit them.

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
