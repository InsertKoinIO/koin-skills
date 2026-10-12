---
name: koin
description: >
  Write and edit Koin dependency injection code in a project that already uses
  Koin 4.x — add or change a repository, use case, ViewModel, service, worker or
  navigation entry; write a definition or a module (including for a new Gradle
  module); inject at an Android, Compose, Ktor or iOS entry point; qualifiers,
  scopes, tests with Koin. Triggers on Koin APIs: koinViewModel, koinInject,
  by inject, @Singleton, @Factory, @KoinViewModel, @Module, @ComponentScan,
  single<T>(), viewModel<T>(), includes, @Named, @ViewModelScope, KoinTestRule.
  NOT for: adding Koin or DI to a project where Koin isn't started → koin-setup.
  Moving from Hilt, Dagger, Toothpick, Kodein, Koin KSP or Koin 3.x →
  di-migration. Debugging, "why is X created twice", memory, performance,
  slow startup, ANRs, checking how the app behaves → koin-diagnose (Kotzilla).
---

# Koin

Write Koin code that fits the project. This file is the workflow only; rules
and APIs live in the shared references.

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
