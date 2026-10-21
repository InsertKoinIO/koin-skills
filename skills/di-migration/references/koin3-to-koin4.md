# Koin 3.x → Koin 4.x + Koin Compiler Plugin Upgrade Reference

> **Setup & versions** — Gradle: `references/gradle.md` · versions: `references/rules.md` §3 · exact syntax: `references/koin-annotations.md` / `references/koin-compiler-plugin-dsl.md`.

This file holds only what changes between Koin 3.x and 4.x. Converting the DSL
itself (Classic / Constructor → Compiler Plugin DSL) is optional and owned by
`references/dsl-to-compiler.md`.

## Progressive Migration

1. **Whole project, once (Step 3)** — Koin 4.x BOM + Compiler Plugin, Koin KSP
   removed. Existing definitions keep their form and are now compile checked,
   every DSL form included (`references/rules.md` §6).
2. **Module by module (loop)** — update each module's 4.x API changes and call
   sites (below), validated before the next one. Converting its definitions to
   Compiler Plugin DSL is optional, on the user's choice.

Nothing is rewritten in place in one pass.

## What changes in 4.x

- **Koin Compiler Plugin** — compile-time graph verification of every DSL form
  (`references/rules.md` §6)
- **Compiler Plugin DSL** (optional style) — `single<T>()`, `factory<T>()`,
  `viewModel<T>()`; the existing `module { }` structure is kept
- **Compose & KMP** — `koin-compose` / `koin-compose-viewmodel`, one API on every target
- **Scope archetypes** — `activityScope { }`, `fragmentScope { }`,
  `viewModelScope { }` (`references/scopes.md`)

## Gradle

```kotlin
// BEFORE — Koin 3.x
dependencies {
    implementation("io.insert-koin:koin-android:3.5.x")
    implementation("io.insert-koin:koin-androidx-compose:3.5.x")
    implementation("io.insert-koin:koin-annotations:1.x")        // optional KSP annotations
    ksp("io.insert-koin:koin-ksp-compiler:1.x")
}
```

AFTER: `references/gradle.md`. Remove KSP for Koin (`references/ksp-to-compiler.md`
if annotations were used).

**Kotlin below 2.3.20 and can't be bumped** — upgrade the Koin runtime to 4.x via
the BOM without the Compiler Plugin, and keep the existing `singleOf(::T)` /
lambda definitions (no compile-time check). Add the Compiler Plugin once Kotlin is
bumped (`references/rules.md` §3, Kotlin bump); converting to Compiler Plugin DSL stays optional.

## API changes

| Koin 3.x | Koin 4.x | Owner |
|---|---|---|
| Classic / Constructor DSL | Unchanged, compile checked — Compiler Plugin DSL (`single<T>()`…) optional | `references/dsl-to-compiler.md` |
| `getViewModel<VM>()` in Compose (`org.koin.androidx.compose`) | `koinViewModel<VM>()` (`org.koin.compose.viewmodel`) | `references/entry-points.md` (ViewModel, Compose) |
| `get<T>()` in a composable | `koinInject<T>()` | `references/entry-points.md` (Compose) |
| `KoinApplication(application = { … })` composable | Android: start in `Application`, nothing in the tree · Compose-started app: `KoinApplication(configuration = koinConfiguration { … })` | `references/entry-points.md` (Compose app start) |
| `KoinContext { }` | Removed (deprecated) | — |
| `scope(named<MyActivity>()) { scoped { … } }` | `scope<MyActivity> { scoped<T>() }`, or an archetype: `activityScope { }` / `fragmentScope { }` / `viewModelScope { }` | `references/scopes.md` |
| `checkModules()` tests | Not emitted — compile-time verification replaces them (the APIs still exist) | `references/rules.md` §6, `references/testing.md` |

## Kotzilla

Koin 4.x works with the Kotzilla SDK for runtime observability. `di-migration`
proposes it before Step 3, on the current version; accepted → install it through the Kotzilla
MCP onboarding flow (`references/kotzilla.md`).
