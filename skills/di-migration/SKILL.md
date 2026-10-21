---
name: di-migration
description: >
  Migrate Kotlin / Android / KMP projects to Koin 4.x with the Koin Compiler Plugin:
  Hilt, Dagger 2, Toothpick and Kodein to Koin, Koin 3.x to 4.x, classic Koin DSL to
  Compiler Plugin DSL, and Koin KSP annotations to the Compiler Plugin. Progressive, module by
  module, keeping the old container running until the last binding moves. Use when
  the user wants to migrate, convert or switch DI frameworks, remove Hilt / Dagger /
  Toothpick / Kodein, upgrade Koin, move off KSP, make the Koin graph compile safe
  or verified at build time, or pastes Hilt / Dagger / Toothpick / Kodein module
  code to convert — "replace Hilt with Koin", "move away from Dagger", "Kodein to
  Koin", "Koin KSP to compiler plugin", "upgrade to Koin 4", "make Koin compile
  safe". When a Koin KSP or Koin 3.x project upgrades AGP, Kotlin, KSP or Gradle,
  it only proposes the move (the Compiler Plugin removes Koin's KSP step) — no
  migration starts unasked. Adding Koin to a project with no DI is koin-setup.
---

# DI Migration Skill

Migrate Kotlin/Android/KMP projects between DI frameworks, targeting **Koin 4.x
with the Koin Compiler Plugin**. The per-source reference files in
`references/` hold the concrete mappings, examples, and bridging patterns —
this file is the contract and the workflow.

## Shared references — read first

Read `references/rules.md` first (non-negotiable). `references/index.md` lists
the other shared references and what each owns — read the owner of any detail
you need instead of inferring from memory.

## Migration rules

1. **Target style by source** (an explicit choice, `rules.md` §1):
   - **Hilt / Dagger / Toothpick / Koin KSP** → Annotations
   - **Kodein / Classic Koin DSL** → Compiler Plugin DSL
2. **Koin KSP projects** — follow the removal checklist in
   `references/ksp-to-compiler.md`.
3. **Progressive migration is universal.** Never rewrite existing DI modules in
   place. Create a new Koin module alongside the old container, move definitions
   one feature/leaf-module at a time, validate after each one (see loop below),
   remove the old framework only when the last binding has moved.

## Supported Migration Paths

All target **Koin 4.x + Koin Compiler Plugin**. Read the relevant reference
before generating code. If the source is ambiguous, ask.

| Source                    | Reference File                     |
|---------------------------|------------------------------------|
| Hilt (+ Dagger)           | `references/hilt-to-koin.md`       |
| Dagger 2 (no Hilt)        | `references/dagger-to-koin.md`     |
| Toothpick                 | `references/toothpick-to-koin.md`  |
| Kodein                    | `references/kodein-to-koin.md`     |
| Koin 3.x                  | `references/koin3-to-koin4.md`     |
| Koin DSL                  | `references/dsl-to-compiler.md`    |
| Koin KSP Annotations      | `references/ksp-to-compiler.md`    |

**Not covered by this skill:** greenfield projects and manual-DI /
service-locator code have no source framework to map from. Use the
`koin-setup` skill instead.

## Progressive Migration

### Where to start — module selection

**Recommended approach: leaf-first, smallest-first, then ack-and-grow.**

Two strategies exist for ordering a multi-module migration:

| Strategy | When | Trade-off |
|----------|------|-----------|
| **Leaf-first** (small leaf/feature modules first, then grow toward core) — **default** | Almost every project | Small early wins, validates the whole 8-step workflow on a low-risk module, builds team confidence with Koin idioms, surfaces tooling/Gradle gotchas before they hit critical code |
| **Bottom-up** (core / data first, then features above) | Rare — only if the core graph is tiny and unambiguous, and feature modules already compile against an interface boundary | Avoids bridging from core into Koin (because nothing depends *on* feature modules), but blocks all feature work until the foundational layer is rewritten and validated |

**Default recommendation: leaf-first.** Start with the **smallest, most peripheral
module** you can find, bridge any dependencies it still has back into the legacy
container, validate the full per-module loop end-to-end, then **get explicit user
acknowledgement** before picking the next target. Each subsequent target moves
one level toward `core` / `data` / `app`. Never jump straight to `AppModule`.

Rank candidates inside the leaf-first strategy and propose the top 1–3; ask
for confirmation before any code:

1. **Leaf modules with zero dependants** (nothing will break upstream)
2. **Few bindings** (≤5) — small blast radius, quick win
3. **Simple binding types only** — no custom scopes, assisted inject, multibindings, Workers
4. **Feature modules, not `core` / `common`** — limited call-site reach
5. **Self-contained call sites** — only used inside their own Gradle module

After each module migrates and passes validation (Step 7), **explicitly ask the
user before moving on**: "next target?", with a fresh ranked list reflecting
what's now eligible. This ack-per-module rhythm is what keeps the migration safe
— it prevents Claude from chaining several migrations without the user catching
a regression.

Defer: `AppModule`, `@EntryPoint`-exposed bindings, Worker/ContentProvider-used
bindings, custom component hierarchies.

Present a ranked table (`Rank | Module | Bindings | Dependants | Complexity |
Recommended?`) before proceeding.

### Per-module validation loop

Migration is a loop, not a waterfall.

**Before the first module — runtime check setup.** Detect Kotzilla
("Detect first" in `references/kotzilla.md`). SDK not in place → offer it
**once, here**: a baseline can't be captured after the first module has moved.
Then, if the SDK is in place:

- **Koin source** (Koin 3.x, classic DSL, Koin KSP) — run the app on the
  current version to capture a **baseline**: the same definitions, before any
  change.
- **Other source** (Hilt, Dagger, Toothpick, Kodein) — Kotzilla doesn't see the
  old container, so there is no baseline. Each migrated definition is checked
  against the behavior its source binding meant ("Expected behavior" in
  `references/kotzilla.md`, with the scope mapping of the per-source
  reference).

The user declines → the loop runs without step 5.

For **each** module:

1. Move the definitions into the new Koin module
2. Update call sites inside that module's Gradle scope
3. Compile — whole project green
4. **Runtime smoke test** — run the app or tests, exercise one code path that
   uses the migrated bindings. A green build is not enough; wiring errors
   (missing `androidContext`, wrong scope, stale bridge call) only surface at runtime
5. **Kotzilla check** (SDK in place) — on a new app version, run the path that
   resolves the migrated definitions and check each one against the baseline
   or its expected behavior (`references/kotzilla.md`). Report each definition
   as verified, a mismatch, or not verified (no session). A mismatch — a
   `@Singleton` migrated to a factory, a scope never closed, a new main-thread
   cost — is fixed before the commit. Bindings still behind a bridge are
   reported as not checkable yet.
6. Commit as a self-contained unit before picking the next module

The loop is `references/rules.md` §10 applied to migration: a small project
(one Gradle module, about five bindings) migrates in one verified step; a
single-module app with more is split by feature (a screen's ViewModel and what
it needs), the rest staying in the old container.

Do not batch un-validated migrations. If validation fails, fix or revert before
touching anything else.

### Bridging with the existing DI

While migrating, Koin definitions may need to consume bindings still in the
old container. Two options:

- **Library bridge (Hilt)** — `koin-dagger-bridge`: `dagger<T>()` returns a
  Hilt `@EntryPoint` interface `T`, then call its accessor. See
  `references/hilt-to-koin.md`.
- **Manual bridge — co-located in the consumer's `@Module`** (recommended).
  `@Singleton fun` for annotations, scope helper (`Scope.toothpick<T>()`,
  `Scope.kodein<T>()`) for Compiler Plugin DSL. Per-source examples in each reference.

A1 per-module verification only sees a module's own bindings — co-located
bridges keep A1 green; sibling aggregators don't. When duplication across
consumers gets painful, promote to a `SharedBridgeModule` (`@Module +
@Configuration`) consumed via `@Module(includes = [...])` (`includes` puts
it in A1's view). Promote on demand, not pre-emptively.

Every bridge is a migration TODO — delete locally when the source moves into Koin.

## Migration Workflow

Steps 4 → 7 are the per-module loop. Step 5 runs once (or once per new app
entry point). Step 8 is the final cleanup after every module has been migrated
and validated.

### Step 1 — Inventory

Scan for every DI-related file: modules, components, entry points, qualifiers,
scopes, workers. Classify each binding (singleton, factory, scoped, assisted,
multibinding, viewModel). Flag anything needing manual attention (custom scopes,
reflection-based injection). Count total bindings.

Present as a table (`# | Source File | Binding Type | Scope | Notes`) before proceeding.

### Step 2 — Plan

Produce:
- Mapping table: source construct → target (from reference file)
- **Ranked migration candidates** (see "Where to start" above) — top 1–3, ask
  user to confirm first target
- For **Kodein**, confirm Compiler Plugin DSL output is what the user expects (annotations
  are explicitly not used for Kodein migrations)
- Risk flags: anything that can't be 1:1 translated
- Gradle changes and version requirements
- Bridging plan if bindings will cross containers during migration

**Stop here.** Present the inventory and the plan, then end your turn: no file
edits until the user confirms the plan, the first target and any Kotlin bump
(`references/rules.md` §3). Skip the stop only when the user's message already
confirms them. Declined → **`koin`** continues the task in the current setup.

### Step 3 — Gradle Setup

**Versions** — per `references/rules.md` §3 (latest on Maven Central, Kotlin
bump cascade).

Then produce the Gradle diff:

1. Remove old DI framework deps (+ kapt/KSP if only used for it)
2. Add Koin per `references/gradle.md` — only the artifacts the project needs
3. Present as a diff with the version source noted (latest Maven Central
   release, or defaults)

### Step 4 — Generate Module Code

Use the target style from migration rule 1. Produce BEFORE/AFTER blocks per
module, following the relevant per-source reference and the style's cheat
sheet. KMP → `expect`/`actual` at any granularity (`@Module` class, annotated
class, or plain function).

### Step 5 — Wire Up Application

Configuration per `references/rules.md` §5 — code in the style's cheat sheet
("App entry point"). Annotations: `@KoinApplication` + `startKoin<App>`, each
Gradle module root discovered. DSL: `startKoin` loads one app module that
`includes(...)` the migrated modules.

### Step 6 — Update Injection Sites

Field injection (`@Inject lateinit var`): at framework entry points (Activity,
Fragment, Service…) → the Koin API for that entry point (`references/entry-points.md`);
in normal classes → constructor injection, never `KoinComponent` (`references/rules.md` §8).
`hiltViewModel()` → `koinViewModel()`, scope access → `references/scopes.md`. Remove
`@AndroidEntryPoint`, `@HiltAndroidApp` and equivalents. Show each changed file with
before/after.

### Step 7 — Per-module validation

**Run after every module, not only at the end.** See "Per-module validation loop"
above for the 6-item checklist. This is the gate before starting the next module.

After validation passes, **stop and ask the user for explicit acknowledgement
before picking the next target.** Re-rank the remaining candidates (something
that was a leaf before may no longer be) and propose the top 1–3. Never chain
multiple module migrations without an ack — the per-module rhythm is what makes
regressions catchable.

Test-config updates belong here: `KoinTestRule` or `startKoin` in test setup,
mock replacement. Graph verification is compile-time (Compiler Plugin) — remove
`checkModules { }` / `verify()` tests. Show before/after for
existing test files.

### Step 8 — Final Cleanup

When the last module has been migrated and validated:

- [ ] All old DI annotations removed (`@Inject`, `@Module`, `@Component`, `@HiltAndroidApp`, etc.)
- [ ] No references to old DI generated classes (`Dagger*Component`, `*_Factory`, `*_MembersInjector`)
- [ ] No imports from old DI packages
- [ ] Every bridge call (`dagger<T>()` / `toothpick<T>()` / `kodein<T>()`) removed
- [ ] Compile-time graph verification re-enabled to strict
- [ ] Old DI deps removed from `build.gradle.kts`; KSP/kapt plugins removed if no longer needed
- [ ] ViewModel injection works in Activities, Fragments, Composables
- [ ] Scoped bindings match original lifecycle semantics — checked in Kotzilla
      session data when the SDK is in place
- [ ] Tests pass

## Parameter Resolution

Constructor and function parameters (`T`, `T?`, `Lazy<T>`, `List<T>`,
`@InjectedParam`, qualifiers, properties) are resolved by the Compiler Plugin —
see "Parameter resolution" in `references/koin-compiler-plugin-dsl.md` and "Parameters &
qualifiers" in `references/koin-annotations.md`. JSR-330 annotations from the
source framework are reused as-is.

## Edge Cases

Read the relevant reference section:

- **Assisted Inject** → `@InjectedParam` + `parametersOf()`
- **Multibindings (Set/Map)** → manual collection assembly in `@Module`
- **Custom Scopes** → `references/scopes.md` (scopes only when an instance must be shared — check with the user)
- **Component Dependencies** → module includes + scoping
- **Lazy / Provider** → `Lazy<T>` constructor parameter (`references/principles.md` rule 7)
- **WorkManager**, **Navigation** → `references/entry-points.md`
- **JSR-330 annotations** → handled natively by the Koin Compiler
- **Custom qualifiers** → reusable as-is

## Kotzilla

Offered once, before the first module; used at loop step 5 of every module
once in place. A runtime question during the migration ("is it slower now?")
goes to Kotzilla at any step. Rules and expected behavior:
`references/kotzilla.md`.

## Context

### Koin Compiler Plugin

- Plugin ID: `io.insert-koin.compiler.plugin` — versions in `references/rules.md` §3
- Inline transformation at compile time — no generated files
- 3-layer safety: A1 (per-module), A2 (config groups), A3 (full graph)
- Supports `@Module`, `@Configuration`, `@KoinApplication`, `@Monitor`, top-level functions
- Full KMP support — no per-target config

### Migration Benefits

When explaining why Koin: "Koin in short" in `references/index.md`. Plus, for a
migration: progressive — Koin and the old container coexist until the last
binding moves.
