# Koin Skills

[![Version](https://img.shields.io/badge/version-2.0.0-blue)](./CHANGELOG.md)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](./LICENSE)
[![Koin](https://img.shields.io/badge/Koin-4.x-orange)](https://insert-koin.io)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.3.20%2B-purple)](https://kotlinlang.org)

Official Koin skills for AI agents, packaged as the **`koin`** Claude Code plugin.
They target **Koin 4.x with the Koin Compiler Plugin**: Koin Annotations (JSR-330 compatible) or Koin DSL,
compile safe in both, for Kotlin, Android, Compose, Kotlin Multiplatform and Ktor.

| Skill | What it does |
|-------|--------------|
| `koin-setup` | Set up Koin in a new or legacy project, or alongside an existing DI container |
| `koin` | Write Koin code: definitions, modules, entry points, scopes, tests — and push back on DI mistakes |
| `di-migration` | Migrate from Hilt, Dagger, Toothpick, Kodein, Koin 3.x, classic Koin DSL or Koin KSP |
| `koin-diagnose` | Koin errors and app behavior (startup, ANRs, scopes), proven with the Kotzilla MCP + SDK |

## Installation

### From Claude Code (recommended)

In a Claude Code session, run:

```
/plugin marketplace add InsertKoinIO/koin-skills
/plugin install koin@koin-skills
```

The first command registers this repo as a plugin marketplace; the second
installs the `koin` plugin from it. Skills show up as `koin:koin-setup`,
`koin:koin`, `koin:di-migration` and `koin:koin-diagnose`. Updates:
`/plugin marketplace update koin-skills`.

### From a clone

`skills/` at the repo root holds the complete, ready-to-use skills — no build step needed.

```bash
git clone https://github.com/InsertKoinIO/koin-skills.git
claude --plugin-dir /path/to/koin-skills
```

Or copy one skill into your Claude Code skills directory (no plugin, skill only):

```bash
# Project-level (shared with your team via git)
mkdir -p .claude/skills/koin
cp -R koin-skills/skills/koin/. .claude/skills/koin/

# Or personal (available across all your projects)
mkdir -p ~/.claude/skills/koin
cp -R koin-skills/skills/koin/. ~/.claude/skills/koin/
```

Copy the whole skill folder: each skill reads its `references/`. Update with `git pull`.

### Other agents

Each [GitHub Release](https://github.com/InsertKoinIO/koin-skills/releases) attaches one
`<skill>-skill.skill` archive per skill (a zip of the skill folder) and `koin-plugin.zip`.

## Supported Migration Paths

| Source | Target |
|--------|--------|
| Hilt (+ Dagger) | Koin 4.x + Compiler Plugin (annotations) |
| Dagger 2 (no Hilt) | Koin 4.x + Compiler Plugin (annotations) |
| Toothpick | Koin 4.x + Compiler Plugin (annotations) |
| Kodein | Koin 4.x Compiler Plugin DSL |
| Koin 3.x | Koin 4.x Compiler Plugin DSL |
| Koin DSL | Koin 4.x Compiler Plugin DSL |
| Koin KSP Annotations | Koin 4.x Annotations + Compiler Plugin |

> For **greenfield projects** or **manual DI / service locator** code, there's
> nothing to migrate *from* — use Koin directly per the official docs at
> [insert-koin.io](https://insert-koin.io) and apply the same Compiler Plugin
> conventions this skill uses.

## Usage

The skills trigger on their own when a task touches dependency injection. Examples:

- "Add Koin to this KMP project"
- "Add a ViewModel for the profile screen" (in a Koin project)
- "Why is `UserRepository` created twice?"

- "Migrate this Hilt module to Koin"
- "Convert my Dagger components to Koin"
- "Upgrade my Koin 3.x project to Koin 4.x"
- "Move from Koin KSP annotations to the Compiler Plugin"
- "Convert this Toothpick scope tree to Koin"
- "Migrate this Kodein DI container to Koin"

For migrations, `di-migration` follows an **8-step workflow**: Inventory → Plan → Gradle Setup → Generate Code → Wire Up → Update Injection Sites → Test Configuration → Verify & Cleanup.

**Progressive migration by default**: the skill recommends creating a new Koin module and moving definitions into it step by step — never rewriting your existing DI modules in place. For Hilt/Dagger projects it also surfaces the `koin-dagger-bridge` bridge so Koin and Hilt can coexist during the migration.

## Key Features

- **Koin Compiler Plugin** (`io.insert-koin.compiler.plugin`) — compile-time dependency verification, zero generated files
- **Auto parameter resolution** — `T`, `T?`, `Lazy<T>`, `List<T>` handled automatically by the compiler
- **Auto-bind** — single interface implementations detected automatically, no explicit `binds` needed
- **JSR-330 support** — `javax.inject.*` and `jakarta.inject.*` annotations reusable as-is
- **Custom qualifiers** — existing `@Qualifier` annotations from Dagger/Hilt work directly
- **Scope archetypes** — `@ActivityScope`, `@FragmentScope`, `@ViewModelScope`, `@ActivityRetainedScope`
- **Compiler Plugin DSL** — `single<T>()`, `factory<T>()`, `viewModel<T>()` with reified type parameters

## Kotzilla MCP Server

`koin-diagnose` (and the other skills at their handoff points) use the **Kotzilla MCP Server** for Koin errors, configuration fixes, best practices and runtime proof.

**Included with the `koin` plugin** in Claude Code: it shows as `plugin:koin:kotzilla`
(needs authentication) until you sign in — run `/mcp`, pick it, sign in with a free
account from https://kotzilla.io. Nothing reaches Kotzilla before you sign in.

Without the plugin, or in another agent (Cursor, Codex, Copilot, Junie…), add the
endpoint `https://mcp.kotzilla.io/mcp` (HTTP transport, OAuth) yourself. With Claude Code:
```bash
claude mcp add kotzilla --transport http https://mcp.kotzilla.io/mcp
```

The skills check that Kotzilla tools are connected, whatever server provides them, before
using them — and tell you how to connect for your agent when they aren't.

## Requirements

- Kotlin ≥ 2.3.20 (K2 compiler)
- Koin 4.2.2+

## Contributing

Issues and pull requests are welcome.

- **Bug reports / migration path gaps** → open an issue with the source framework, a minimal snippet, and the expected Koin output
- **Edit the sources under `src/`, never `skills/`** — `skills/` is generated by `./build.sh` and committed; run it and commit both
- **New migration paths** → add a `src/skills/di-migration/references/<source>-to-koin.md` guide following the existing structure, register it in `src/skills/di-migration/SKILL.md`, then run `./build.sh`
- **Release** (maintainers): see [RELEASING.md](./RELEASING.md) for the full checklist

## Repository Layout

```
.claude-plugin/
  plugin.json                       # plugin manifest (name, version, metadata)
  marketplace.json                  # makes this repo installable via /plugin marketplace add
src/skills/<name>/                  # skill sources: SKILL.md + skill-specific references/
src/shared/*.md                     # references shared by every skill, written once
skills/<name>/                      # GENERATED by ./build.sh, committed: complete skills (the installed plugin)
build.sh                            # checks sources, generates skills/, builds build/*.skill + build/koin-plugin.zip
```

## License

Apache 2.0 — see [LICENSE](./LICENSE).
