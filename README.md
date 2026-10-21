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
| `di-migration` | Migrate from Hilt, Dagger, Toothpick, Kodein, Metro, Koin 3.x, classic Koin DSL or Koin KSP |
| `koin-diagnose` | Koin errors and app behavior (startup, ANRs, scopes): static suspects, proven with Kotzilla when you opt in |

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
| Hilt (+ Dagger) | Koin 4.x Annotations + Compiler Plugin |
| Dagger 2 (no Hilt) | Koin 4.x Annotations + Compiler Plugin |
| Toothpick | Koin 4.x Annotations + Compiler Plugin |
| Kodein | Koin 4.x Compiler Plugin DSL |
| Metro | Koin 4.x Annotations + Compiler Plugin |
| Koin 3.x | Koin 4.x + Compiler Plugin (DSL kept; Compiler Plugin DSL optional) |
| Koin DSL | Add the Compiler Plugin (DSL kept; Compiler Plugin DSL optional) |
| Koin KSP Annotations | Koin 4.x Annotations + Compiler Plugin |

> For **greenfield projects** or **manual DI / service locator** code, there's
> nothing to migrate *from* — the `koin-setup` skill sets Koin up directly.

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

For migrations, `di-migration` follows an **8-step workflow**: Inventory → Plan → Gradle Setup → Generate Module Code → Wire Up Application → Update Injection Sites → Per-module validation → Final Cleanup. Steps 4, 6 and 7 repeat module by module (Step 5 with the first module).

**Progressive migration by default**: the skill recommends creating a new Koin module and moving definitions into it step by step — never rewriting your existing DI modules in place. While both containers run, Koin reads from the old one through bridges: `koin-dagger-bridge` (`dagger<T>()` on a Hilt `@EntryPoint`) for Hilt, `@Singleton fun` providers for plain Dagger 2, scope helpers for Toothpick and Kodein, graph accessors for Metro.

## Key Features

- **Koin Compiler Plugin** (`io.insert-koin.compiler.plugin`) — compile-time dependency verification for Annotations and every Koin DSL form
- **Auto parameter resolution** — `T`, `T?`, `Lazy<T>`, `List<T>` handled automatically by the compiler
- **Auto-bind** — a class is bound to the interfaces it implements, no explicit `binds` needed
- **JSR-330 support** — `javax.inject.*` and `jakarta.inject.*` annotations reusable as-is
- **Custom qualifiers** — existing `@Qualifier` annotations from Dagger/Hilt work directly
- **Scope archetypes** — `@ActivityScope`, `@FragmentScope`, `@ViewModelScope`, `@ActivityRetainedScope`
- **Compiler Plugin DSL** — `single<T>()`, `factory<T>()`, `viewModel<T>()` with reified type parameters

## Kotzilla MCP Server

Kotzilla is **optional**: the skills work fully without it. They propose it once, at a
precise moment, and never force it: `koin-diagnose` for Koin errors, crashes and runtime
behavior (startup, ANRs, memory, instances created twice), `di-migration` to check each
migrated module at runtime, `koin-setup` and `koin` to see new definitions behave as
written. The **Kotzilla MCP Server** alone diagnoses Koin errors; the Kotzilla SDK adds
real session data for runtime behavior. Decline once and no skill asks again in that
conversation.

**Included with the `koin` plugin** in Claude Code: it shows as `plugin:koin:kotzilla`
(needs authentication) until you sign in — run `/mcp`, pick it, sign in with a free
account from https://kotzilla.io. Nothing reaches Kotzilla before you sign in.

Without the plugin, or in another agent (Cursor, Codex, Copilot, Junie…), add the
endpoint `https://mcp.kotzilla.io/mcp` (HTTP transport, OAuth) yourself. With Claude Code:
```bash
claude mcp add kotzilla --transport http https://mcp.kotzilla.io/mcp
```

The skills check whether Kotzilla tools are connected, whatever server provides them. When
they aren't, the proposal says how to connect for your agent; you sign in and run any install
yourself — the agent never does it for you.

## Requirements

- Kotlin ≥ 2.3.20 (K2 compiler)
- Koin ≥ 4.2.2, Koin Compiler Plugin ≥ 1.2.1 (recommended; Koin DSL also works without it)

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
build/                              # git-ignored: build/plugin/, <skill>-skill.skill bundles, koin-plugin.zip
scripts/                            # build checks (duplication, generated output)
```

## License

Apache 2.0 — see [LICENSE](./LICENSE).
