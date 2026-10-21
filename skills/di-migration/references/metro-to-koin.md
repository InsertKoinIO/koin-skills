# Metro → Koin 4.x + Koin Compiler Plugin Migration Reference

> **Setup & versions** — Gradle: `references/gradle.md` · versions: `references/rules.md` §3 · exact syntax: `references/koin-annotations.md`.

Target style: **Koin Annotations**.

## Table of Contents
1. [Progressive Migration](#progressive-migration)
2. [Core Concept Mapping](#core-concept-mapping)
3. [Gradle Changes](#gradle-changes)
4. [Bindings](#bindings)
5. [Qualifiers](#qualifiers)
6. [Retrieval](#retrieval)
7. [Graph extensions → Scopes](#graph-extensions-to-scopes)
8. [ViewModels](#viewmodels)
9. [Compose](#compose)
10. [Android entry points](#android-entry-points)
11. [KMP](#kmp)
12. [Testing](#testing)
13. [Cleanup](#cleanup)

---

## Progressive Migration

Metro and Koin run side by side until the last binding moves. No bridge
library — the bridge is co-located in each consumer feature ("Metro" in
`references/bridging.md`).

1. **Step 3** — add Koin next to Metro; the Metro plugin and graphs stay.
2. **Shared start** — the Metro graph is created first and kept in the bridge
   holder, then `startKoin<KoinApp>()` in the shared `initApp()` ("Two
   containers at startup" in `references/bridging.md`).
3. **Per feature (loop)** — move its bindings to Koin annotations. A binding it
   still needs from Metro → one function in the feature's `MetroBridgeModule`,
   deleted when that binding moves. Metro code that needs a moved binding →
   "The other direction" in `references/bridging.md`.
4. **Step 8** — the graphs, the holder and the Gradle plugin go ("Cleanup").

---

## Core Concept Mapping

| Metro | Koin Annotations |
|---|---|
| `@DependencyGraph(AppScope::class)`, one per platform (often extending a common graph) | One `@KoinApplication object KoinApp`; `startKoin<KoinApp>()` in the shared `initApp()` — "KMP" below |
| `@DependencyGraph.Factory` `@Provides` / `@Includes` arguments | Startup values — "Values known at startup" in `references/entry-points.md` |
| `@Provides` directly in the `@DependencyGraph` | `@Singleton` / `@Factory` function in a `@Module` of the Gradle module that owns the type |
| `@Provides` in a `@ContributesTo` interface or `@BindingContainer` | `@Module` class with `@Singleton` / `@Factory` functions, included by the feature's `@Configuration` module (`references/rules.md` §7) |
| `@Inject class` (unscoped) | `@Factory` |
| `@Inject @SingleIn(AppScope::class)` | `@Singleton` |
| `@ContributesBinding` | On the impl: `@Singleton` if `@SingleIn`, else `@Factory` — auto-bound |
| `@Binds` | Auto-bind on the impl; `binds = [...]` with several interfaces |
| Platform `@BindingContainer` | `@Module expect class PlatformModule` (`references/rules.md` §7) |
| `@GraphExtension` + `@GraphExtension.Factory` | Scope — "Graph extensions" below |
| `@Qualifier`, `@Named` (Metro) | Re-declared with Koin or JSR-330 — "Qualifiers" below |
| `@AssistedInject` / `@Assisted` / `@AssistedFactory` | `@InjectedParam` + `parametersOf(…)`; factory deleted |
| `@ContributesIntoSet`, `@IntoSet`, `@ElementsIntoSet` | Each element a `@Named` definition bound to `T`; inject `List<T>` — "Multibindings" in `references/dagger-to-koin.md` |
| `@IntoMap` / `@ContributesIntoMap` outside ViewModels (`@StringKey`, `@ClassKey`…) | Same pattern; the consumer keys the list — "Multibindings" in `references/dagger-to-koin.md` |
| `@Multibinds(allowEmpty = true)` | Deleted — `List<T>` is empty when no element |
| `Lazy<T>` / `Provider<T>` | "Lazy and Provider" in `references/dagger-to-koin.md` |
| Graph accessors (`val x: X`) | Deleted — kept only while a bridge reads them |

---

## Gradle Changes

### Add Koin (Step 3)

Per `references/gradle.md`: Compiler Plugin, `koin-bom`, `koin-annotations`,
`koin-compose-viewmodel` (`commonMain`), `koin-android` (Android). Metro stays.

### Remove Metro — Step 8

- Plugin `dev.zacsweers.metro`; `metrox-viewmodel`, `metrox-viewmodel-compose`,
  `metrox-android`
- Metro ProGuard / R8 rules; `tools:ignore="Instantiatable"` on Activities
  built by `MetroAppComponentFactory`

---

## Bindings

```kotlin
// BEFORE
@Inject @SingleIn(AppScope::class) @ContributesBinding(AppScope::class)
class UserRepositoryImpl(private val api: Api) : UserRepository

@BindingContainer @ContributesTo(AppScope::class)
object NetworkProviders {
    @Provides @SingleIn(AppScope::class) fun httpClient(): HttpClient = HttpClient()
}

// AFTER
@Singleton                                  // auto-bound to UserRepository
class UserRepositoryImpl(private val api: Api) : UserRepository

@Module
class NetworkModule {
    @Singleton fun httpClient(): HttpClient = HttpClient()
}
```

---

## Qualifiers

Metro's `@Qualifier` / `@Named` aren't recognized: re-declare the annotation,
keep every use site.

```kotlin
// BEFORE
@dev.zacsweers.metro.Qualifier annotation class Year

// AFTER
@org.koin.core.annotation.Qualifier annotation class Year   // or javax.inject.Qualifier
```

---

## Retrieval

| Metro | Koin |
|---|---|
| Constructor parameter | Unchanged |
| `graph.userRepository` in an entry point | `by inject()` / `koinInject()` — `references/entry-points.md` |
| Member injection `fun inject(target: X)` on the graph | `by inject()` in the entry point; constructor injection elsewhere (`references/rules.md` §8) |
| Graph read from Swift | Exported function or bridge class — "iOS / Swift" in `references/entry-points.md` |

---

## Graph extensions to Scopes

A `@GraphExtension` that follows an Activity, a Fragment or a ViewModel → that
scope archetype; any other one (a session, a runtime value) → a custom scope —
"Choose the scope" in `references/scopes.md`.

```kotlin
// BEFORE
@GraphExtension(YearScope::class)
interface YearGraph {
    val api: YearlyApi
    @ContributesTo(AppScope::class) @GraphExtension.Factory
    interface Factory { fun create(@Provides @Year year: Int): YearGraph }
}
@Inject @SingleIn(YearScope::class)
class YearlyApi(@Year private val year: Int, private val client: HttpClient)

// AFTER — custom scope, a runtime value
@Scope(YearScope::class) @Scoped
class YearlyApi(@Provided @Year private val year: Int, private val client: HttpClient)  // @Year re-declared ("Qualifiers")
```

The factory becomes the scope owner ("Scope with a runtime value" in
`references/scopes.md`). Metro let the old child graph go to the GC; a Koin
scope stays registered until the owner closes it.

---

## ViewModels

| Metro (metrox-viewmodel) | Koin |
|---|---|
| `@Inject @ViewModelKey @ContributesIntoMap(AppScope::class)`, `metroViewModel()` | `@KoinViewModel`, `koinViewModel()` |
| `@AssistedFactory @ViewModelAssistedFactoryKey(VM::class)` `Factory : ViewModelAssistedFactory` (reads `CreationExtras`), `assistedMetroViewModel<VM>()` | Factory deleted; a saved-state value → `SavedStateHandle` parameter, a caller value → `@InjectedParam` + `koinViewModel { parametersOf(x) }` |
| `@AssistedFactory @ManualViewModelAssistedFactoryKey` `Factory : ManualViewModelAssistedFactory` | Deleted; `@InjectedParam` on the parameter |
| `assistedMetroViewModel<VM, VM.Factory>(key = k) { create(x) }` | `koinViewModel<VM>(key = k) { parametersOf(x) }` — keep the key |
| `ViewModelGraph`, the `MetroViewModelFactory` subclass, `defaultViewModelProviderFactory` overrides | Deleted with the last ViewModel |

---

## Compose

`metroViewModel()` → `koinViewModel()`; a graph accessor read in a composable →
`koinInject()` (`references/entry-points.md`, Compose). The
`CompositionLocalProvider(LocalMetroViewModelFactory provides …)` at the root
is deleted with the last Metro ViewModel.

---

## Android entry points

metrox-android builds Activities and Receivers by constructor
(`MetroApplication`, `MetroAppComponentFactory`, `@ActivityKey`,
`@BroadcastReceiverKey`). Koin: `by inject()` in the Activity, `KoinComponent`
in the Receiver (`references/entry-points.md`). They read the graph directly:
move them in the same step as the bindings they use, or keep them in Metro
behind "The other direction" in `references/bridging.md`.

---

## KMP

Metro: one `@DependencyGraph` per platform, each created by its entry point.
Koin: one shared start, each platform adds its values; platform bindings in
`@Module expect class PlatformModule` (`references/rules.md` §7).

```kotlin
// BEFORE
@DependencyGraph(AppScope::class)
interface AndroidAppGraph : AppGraph {
    @DependencyGraph.Factory
    fun interface Factory { fun create(@Provides application: Application): AndroidAppGraph }
}
class MainApplication : Application() {
    val graph by lazy { createGraphFactory<AndroidAppGraph.Factory>().create(this) }
}

// AFTER — commonMain
@KoinApplication object KoinApp

fun initApp(platformConfig: KoinAppDeclaration? = null) =
    startKoin<KoinApp> { platformConfig?.invoke(this) }

// androidMain
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        initApp { androidContext(this@MainApplication) }
    }
}
// iOS: Swift calls initApp() — "iOS / Swift" in references/entry-points.md
```

While Metro still runs, each platform creates its graph and sets the bridge
holder before `initApp()` ("Metro" in `references/bridging.md`).

---

## Testing

Metro test graphs (`excludes = […]`, `replaces = […]` contributions) →
`KoinTestRule` with only the modules the test needs, fakes as overrides —
`references/testing.md`.

---

## Cleanup

- No `dev.zacsweers.metro` / `dev.zacsweers.metrox` import; per-platform graphs,
  `MetroApplication`, the `MetroBridge` holder, every `MetroBridgeModule` and
  `<Feature>MetroAccessors` interface deleted
- Gradle and ProGuard per "Remove Metro" above
