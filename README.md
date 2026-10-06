# Koin Migration

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](./CHANGELOG.md)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](./LICENSE)
[![Koin](https://img.shields.io/badge/Koin-4.x-orange)](https://insert-koin.io)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.3.20%2B-purple)](https://kotlinlang.org)

Migration guide and AI-assisted tooling for moving Kotlin / Android / KMP projects to **Koin 4.x with the Koin Compiler Plugin**.

This repository is two things in one:

- **Reference documentation** — per-framework migration guides under [`skills/di-migration/references/`](./skills/di-migration/references) covering Hilt, Dagger, Toothpick, Kodein, and Koin DSL / KSP upgrades
- **Claude Code plugin** — the same content packaged as an AI skill (`koin-migration`) that Claude can use to automate migrations directly in your codebase

## Installation

### From Claude Code (recommended)

In a Claude Code session, run:

```
/plugin marketplace add InsertKoinIO/koin-migration
/plugin install koin-migration@koin-migration
```

The first command registers this repo as a plugin marketplace; the second
installs the `koin-migration` plugin from it. Updates: re-run
`/plugin install koin-migration@koin-migration` after a new release.

### Manual install

```bash
git clone https://github.com/InsertKoinIO/koin-migration.git
```

Run Claude Code pointing at the cloned directory:

```bash
claude --plugin-dir /path/to/koin-migration
```

Or copy only the skill into your Claude Code skills directory (no plugin manifest, skill only):

```bash
# Project-level (shared with your team via git)
mkdir -p .claude/skills/di-migration
cp -r koin-migration/skills/di-migration/* .claude/skills/di-migration/

# Or personal (available across all your projects)
mkdir -p ~/.claude/skills/di-migration
cp -r koin-migration/skills/di-migration/* ~/.claude/skills/di-migration/
```

Update with `git pull`.

## Supported Migration Paths

| Source | Target |
|--------|--------|
| Hilt (+ Dagger) | Koin 4.x + Compiler Plugin (annotations) |
| Dagger 2 (no Hilt) | Koin 4.x + Compiler Plugin (annotations) |
| Toothpick | Koin 4.x + Compiler Plugin (annotations) |
| Kodein | Koin 4.x + Compiler Plugin (Safe DSL) |
| Koin 3.x | Koin 4.x Safe DSL + Compiler Plugin |
| Koin DSL | Koin 4.x Safe DSL + Compiler Plugin |
| Koin KSP Annotations | Koin 4.x Annotations + Compiler Plugin |

> For **greenfield projects** or **manual DI / service locator** code, there's
> nothing to migrate *from* — use Koin directly per the official docs at
> [insert-koin.io](https://insert-koin.io) and apply the same Safe DSL + Compiler
> Plugin conventions this skill uses.

## Usage

Ask Claude to migrate your DI code. Examples:

- "Migrate this Hilt module to Koin"
- "Convert my Dagger components to Koin"
- "Upgrade my Koin 3.x project to Koin 4.x"
- "Move from Koin KSP annotations to the Compiler Plugin"
- "Convert this Toothpick scope tree to Koin"
- "Migrate this Kodein DI container to Koin"

The skill follows an **8-step workflow**: Inventory → Plan → Gradle Setup → Generate Code → Wire Up → Update Injection Sites → Test Configuration → Verify & Cleanup.

**Progressive migration by default**: the skill recommends creating a new Koin module and moving definitions into it step by step — never rewriting your existing DI modules in place. For Hilt/Dagger projects it also surfaces the `koin-android-dagger` bridge so Koin and Hilt can coexist during the migration.

## Key Features

- **Koin Compiler Plugin** (`io.insert-koin.compiler.plugin`) — compile-time dependency verification, zero generated files
- **Auto parameter resolution** — `T`, `T?`, `Lazy<T>`, `List<T>` handled automatically by the compiler
- **Auto-bind** — single interface implementations detected automatically, no explicit `binds` needed
- **JSR-330 support** — `javax.inject.*` and `jakarta.inject.*` annotations reusable as-is
- **Custom qualifiers** — existing `@Qualifier` annotations from Dagger/Hilt work directly
- **Scope archetypes** — `@ActivityScope`, `@FragmentScope`, `@ViewModelScope`, `@ActivityRetainedScope`
- **Safe DSL** — `single<T>()`, `factory<T>()`, `viewModel<T>()` with reified type parameters

## Kotzilla MCP Server

During and after migration, use the **Kotzilla MCP Server** for AI-assisted help with Koin configuration fixes, best practices, and debugging.

Register a free account at https://kotzilla.io.

MCP Server endpoint: `https://mcp.kotzilla.io/mcp` (HTTP transport, requires authentication).

Example with Claude Code:
```bash
claude mcp add kotzilla --transport http https://mcp.kotzilla.io/mcp
```

## Requirements

- Kotlin ≥ 2.3.20 (K2 compiler)
- Koin 4.2.2+

## Contributing

Issues and pull requests are welcome.

- **Bug reports / migration path gaps** → open an issue with the source framework, a minimal snippet, and the expected Koin output
- **New migration paths** → add a `references/<source>-to-koin.md` guide following the existing structure, register it in `skills/di-migration/SKILL.md`, then run `./build.sh`
- **Build** the plugin locally: `./build.sh` (produces `koin-migration-plugin.zip` and `di-migration-skill.skill`)
- **Release** (maintainers): see [RELEASING.md](./RELEASING.md) for the full checklist

## Repository Layout

```
.claude-plugin/
  plugin.json                       # plugin manifest (name, version, metadata)
  marketplace.json                  # makes this repo installable via /plugin marketplace add
skills/di-migration/
  SKILL.md                          # skill entry point
  references/*.md                   # per-path migration guides
  evals/evals.json                  # evaluation cases
build.sh                            # validates + packages the plugin
```

## License

Apache 2.0 — see [LICENSE](./LICENSE).
