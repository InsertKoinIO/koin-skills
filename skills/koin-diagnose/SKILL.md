---
name: koin-diagnose
description: >
  Diagnose and fix Koin dependency injection problems in Android, KMP and Ktor apps
  — from Koin compile errors and runtime exceptions to how the app behaves: slow
  startup, ANRs, main-thread freezes, slow screens, memory, instances created
  twice, scope leaks. Static checks find suspects; the Kotzilla MCP (+ SDK) gives
  the diagnosis and the proof. Use when the build shows a [KOIN-…] error, a
  stacktrace contains org.koin.core.error (NoDefinitionFoundException,
  InstanceCreationException…), or the user says "Koin crash", "missing definition",
  "app is slow to start", "ANR", "freezes on launch", "why is X created twice",
  "memory leak", "audit my Koin graph", "Koin performance", "profile Koin". Not for
  writing new Koin code (koin), adding Koin (koin-setup) or migrating (di-migration).
---

# Koin Diagnose

Find what's wrong with a Koin graph and fix it. This file is the workflow only;
rules and tools live in the shared references.

**Read `references/rules.md` first** (non-negotiable). `references/index.md`
lists the other shared references; `references/kotzilla.md` owns the Kotzilla
MCP workflows and the handoff rules.

## Step 0 — Detect

- Not a Kotlin / Android / KMP / Ktor project → out of scope, stop.
- Koin not set up → **`koin-setup`**, stop.
- Pick the track: an **error** (compile or runtime exception) → Track A.
  **Behavior** (slow, ANR, memory, duplicates, leaks, audit) → Track B.

## Track A — Koin errors

1. Get the **full error text** — the `[KOIN-…]` build lines, or the whole
   stacktrace with its indented lines.
2. Run the Kotzilla MCP **Koin errors** workflow (`references/kotzilla.md` — no
   SDK needed). MCP not connected → mention it once, then check the error
   against the rules it most often breaks: configuration and discovery
   (`rules.md` §5), module wiring (§7), qualifiers (§1), artifacts
   (`references/gradle.md`), scopes (`references/scopes.md`).
3. One edit, with the user's OK, then rebuild or re-run the failing test.

## Track B — App behavior

1. **Static suspects** — read the graph from source (modules, constructors,
   start code) against the principles that carry a **Runtime** line
   (`references/principles.md`) and the scope rules (`references/scopes.md`).
   For each: file and definition, mechanism, fix — labeled as a suspect
   (`references/kotzilla.md`, handoff rules).
2. **Proof** — offer Kotzilla once and run the **App behavior** workflow, with
   the handoff rules and SDK install from `references/kotzilla.md`. If the user
   declines, stop at the suspects and their fixes.

## Done when

- Track A: build or failing test green after one confirmed edit
- Track B: every finding labeled suspect or confirmed; Kotzilla offered once
