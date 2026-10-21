# Koin 3.x → Koin 4.x + Koin Compiler Plugin Upgrade Reference

> **Setup & versions** — Gradle: `references/gradle.md` · versions: `references/rules.md` §3 · exact syntax: `references/koin-annotations.md` / `references/koin-compiler-plugin-dsl.md`.

This file holds only what changes between Koin 3.x and 4.x. Converting the DSL
itself (classic / constructor → Compiler Plugin DSL) is owned by `references/dsl-to-compiler.md`.

## What changes in 4.x

- **Koin Compiler Plugin** — compile-time graph verification, no generated files
  (`references/rules.md` §6)
- **Compiler Plugin DSL** — `single<T>()`, `factory<T>()`, `viewModel<T>()`; the existing
  `module { }` structure is kept, only the definitions change
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
lambda definitions (no compile-time check). Do the Compiler Plugin DSL step once Kotlin is
bumped (`references/rules.md` §3, Kotlin bump).

## API changes

| Koin 3.x | Koin 4.x | Owner |
|---|---|---|
| Classic / constructor DSL | Compiler Plugin DSL (`single<T>()`…) | `references/dsl-to-compiler.md` |
| `getViewModel<VM>()` in Compose (`org.koin.androidx.compose`) | `koinViewModel<VM>()` (`org.koin.compose.viewmodel`) | `references/entry-points.md` (ViewModel, Compose) |
| `get<T>()` in a composable | `koinInject<T>()` | `references/entry-points.md` (Compose) |
| `KoinApplication(application = { … })` composable | Android: start in `Application`, nothing in the tree · Compose-started app: `KoinApplication(configuration = koinConfiguration { … })` | `references/entry-points.md` (Compose app start) |
| `KoinContext { }` | Removed (deprecated) | — |
| `scope(named<MyActivity>()) { scoped { … } }` | `scope<MyActivity> { scoped<T>() }`, or an archetype: `activityScope { }` / `fragmentScope { }` / `viewModelScope { }` | `references/scopes.md` |
| `checkModules()` tests | Removed — compile-time verification | `references/rules.md` §6, `references/testing.md` |

## Kotzilla

Koin 4.x works with the Kotzilla SDK for runtime observability. Install it
through the Kotzilla MCP onboarding flow — `references/kotzilla.md`.
