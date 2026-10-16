---
name: koin
description: >
  Use for the dependency-injection part of ANY task in a Kotlin, Android, Compose,
  KMP or Ktor project that uses Koin, even when the request never mentions DI or
  Koin: adding a feature, screen, ViewModel, repository, use case, service, worker
  or Gradle module; adding Navigation 3; writing unit or instrumented tests;
  refactoring or splitting modules; upgrading AGP, Kotlin or Gradle. Load it
  alongside other skills (Android, Compose, navigation, testing, build) whenever
  the change creates, injects or wires a class. Covers definitions, modules,
  entry points, qualifiers, scopes, Koin tests, and pushing back on DI mistakes:
  a ViewModel as single, an Activity in a singleton, I/O in a constructor,
  parametersOf for dependencies. Koin APIs: koinViewModel, koinInject, by inject,
  @Singleton, @KoinViewModel, @Module, single<T>(), viewModel<T>(). Koin not set
  up → koin-setup. Hilt, Dagger, Toothpick, Kodein, Koin KSP or Koin 3.x →
  di-migration. Crashes, slow startup, instances created twice, memory →
  koin-diagnose.
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

- Koin not set up → **`koin-setup`**. Another DI framework, Koin KSP or Koin
  3.x → **`di-migration`**.
- Note the project's **style** (Annotations, or DSL: Safe / autowire / classic)
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

The feature's module, placed and wired per `rules.md` §5 and §7.

## Step 3 — Inject at the entry point

The Koin API for that entry point — `references/entry-points.md`.
`KoinComponent` only per `rules.md` §8 (state the cost, get the user's OK).

## Step 4 — Verify

Build — fix what the compile-time graph check reports (`rules.md` §6). Tests:
`references/testing.md`.

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
