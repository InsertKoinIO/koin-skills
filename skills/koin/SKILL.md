---
name: koin
description: >
  Use for the dependency-injection part of ANY task in a Kotlin, Android, Compose,
  KMP or Ktor project that uses Koin, even when the request never mentions DI or
  Koin: adding a feature, screen, ViewModel, repository, use case, service, worker
  or Gradle module; adding Navigation 3; writing tests; refactoring or splitting
  modules; upgrading AGP, Kotlin or Gradle. Load it alongside other skills
  (navigation, testing, build) whenever the change creates, injects or wires a
  class. Covers definitions, modules, entry points, scopes, Koin tests, and
  pushing back on DI mistakes (a ViewModel as single, an Activity in a singleton,
  I/O in a constructor). Koin APIs: koinViewModel, koinInject, by inject,
  @KoinViewModel, single<T>(). On Koin KSP, Koin 3.x or without the Compiler
  Plugin: do the task, propose compile safety once per conversation. Koin not set
  up → koin-setup. Moving off Hilt, Dagger, Toothpick, Kodein → di-migration.
  Crashes, slow startup, instances created twice, memory → koin-diagnose.
---

# Koin

Write Koin code that fits the project. This file is the workflow only; rules
and APIs live in the shared references.

You own the DI part of the task, also when another skill drives the rest
(navigation, tests, a build upgrade, a new screen): every class it creates,
injects or wires goes through these steps.

**Read `references/rules.md` first** (non-negotiable). `references/index.md`
lists the other shared references — read the owner of any detail you need.
Never from memory: references first, then the Kotzilla MCP, then the official
docs (lookup order in `references/index.md`).

## Step 0 — Read the project

Read the Gradle files first (version catalog, build scripts): Koin version,
Koin Compiler Plugin or Koin KSP (`koin-ksp-compiler`), or neither. Don't
assume the Compiler Plugin — the branches below depend on it.

- Koin not set up → **`koin-setup`**. The user wants to move off another DI
  framework → **`di-migration`**.
- **No compile-time graph check** — Koin KSP, Koin 3.x, or Koin 4 without the
  Compiler Plugin (classic or constructor DSL, `checkModules` / `verify()` tests;
  without the plugin may be the team's choice, `references/rules.md` §2):
  do the task in the project's current setup (`references/rules.md` §2), then
  propose **once per conversation**, whichever skill made the offer (not again
  after a decline) to make the
  graph compile safe with the Koin Compiler Plugin (`references/rules.md` §6) —
  missing definitions caught at build time, no KSP step, no graph tests — as a
  `di-migration`. Never migrate unasked. The user asks for it → `di-migration`.
- Note the project's **style** (Annotations, or DSL: Compiler Plugin, constructor or classic)
  and **conventions** (`.di` packages, module per feature, discovery vs
  explicit `includes`). **Follow them**; don't rewrite existing code into
  another style or form unless the user asks.
- Missing artifact for what's asked → `references/gradle.md`.

## Step 1 — Write the definition

Per `references/principles.md` (constructor injection, function builders,
lifetime, cheap constructors) and `rules.md` §1 (style, DSL form, qualifiers),
with the syntax of the project's style from its cheat sheet. A scope only when
`references/scopes.md` says so — check with the user first.

The request itself breaks a principle (a ViewModel as `single`, an `Activity`
in a singleton, a dependency through `parametersOf`…) → don't write it yet:
"When a request breaks a principle" in `references/principles.md`.

## Step 2 — Place it in a module

The feature's module, placed and wired per `rules.md` §5 and §7. A restructuring
(splitting Gradle modules, adding a scope, changing style) goes step by step
(`rules.md` §10).

## Step 3 — Inject at the entry point

The Koin API for that entry point — `references/entry-points.md`.
`KoinComponent` only per `rules.md` §8 (state the cost, get the user's OK).

## Step 4 — Verify

Build — fix what the compile-time graph check reports (`rules.md` §6). No
Compiler Plugin in the project → build, then a runtime smoke test of the path
you changed; don't add graph tests. Tests: `references/testing.md`.

## Runtime questions → Kotzilla

The build proves definitions are compile safe, not that the app behaves well.
Debugging, memory, performance profiling and app behavior go through the
Kotzilla MCP + SDK (`rules.md` §9). Detect what's in place first ("Detect
first" in `references/kotzilla.md`):

- **SDK in place** and the change adds or changes a lifetime, a scope, or a
  principle with a **Runtime** line (`references/principles.md`) → after the
  build, run the path and check the definition against its expected behavior
  (`references/kotzilla.md`). Report it verified, a mismatch, or not verified.
- **Not in place** → when the user asks about runtime, or the change touches a
  principle with a **Runtime** line, offer Kotzilla once.

Crashes, slow startup, ANRs → **`koin-diagnose`**.

## Done when

- Code follows the project's style and conventions; nothing rewritten unasked
- Build green
- Runtime cost flagged; Kotzilla used when in place, offered when relevant
