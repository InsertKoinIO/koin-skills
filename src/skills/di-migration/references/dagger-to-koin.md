# Dagger 2 → Koin 4.x + Koin Compiler Plugin Migration Reference

> **Setup & versions** — Gradle: `references/gradle.md` · versions: `references/rules.md` §3 · exact syntax: `references/koin-annotations.md` / `references/koin-compiler-plugin-dsl.md`.

## Table of Contents
1. [Progressive Migration](#progressive-migration)
2. [Core Concept Mapping](#core-concept-mapping)
3. [Gradle Changes](#gradle-changes)
4. [Component → Module Conversion](#component-to-module)
5. [Subcomponents → Scopes](#subcomponents-to-scopes)
6. [Injection Patterns](#injection-patterns)
7. [Qualifiers](#qualifiers)
8. [Multibindings](#multibindings)
9. [Component Dependencies](#component-dependencies)
10. [Custom Scopes](#custom-scopes)
11. [Lazy and Provider](#lazy-and-provider)

---

## Progressive Migration

Do **not** rewrite existing Dagger components in place. Create a new empty Koin
module alongside the Dagger graph, move definitions one feature at a time, keep
both running side by side until the last `@Component` is gone.

Dagger 2 has no generic entry-point accessor: Koin reads Dagger bindings through
a `@Singleton fun` over your own `@Component` methods, co-located in the
consumer's `@Module` — `koin-dagger-bridge` is Hilt-only. Pattern, startup
ordering and cleanup: `references/bridging.md`.

Gradle convention plugins: see "Convention plugins" in `references/gradle.md`.

---

## Core Concept Mapping

| Dagger 2 Concept              | Koin Compiler Plugin Equivalent                    |
|-------------------------------|-----------------------------------------------------|
| `@Component`                  | `@Module` + `@KoinApplication` + `startKoin<T>()`  |
| `@Subcomponent`               | A scope archetype (`@ActivityScope`…) when it follows that lifecycle; otherwise `@Scope(T::class)` + `@Scoped` |
| `@Module` + `@Provides`       | `@Module` class with `@Singleton`/`@Factory` functions |
| `@Module` + `@Binds`          | `@Singleton` on impl (auto-binds to interface)          |
| `@Inject constructor`         | `@Factory` on class (new instance per injection)        |
| `@Singleton`                  | `@Singleton`                                            |
| `@Reusable`                   | `@Singleton` (closest approximation)                   |
| `@Component.Factory` / `@Component.Builder` | `startKoin { }`; each `@BindsInstance` argument → a startup value: `androidContext`, `koin.declare` + `@Provided`, or `@Property` ("Values known at startup" in `references/entry-points.md`) |
| `@Subcomponent.Factory` argument | A value declared into the scope when it opens ("Scope with a runtime value" in `references/scopes.md`) |
| `MembersInjector`             | `by inject()` delegate or `get()` direct            |
| Custom `@Qualifier`           | **Reuse as-is** — works directly with Koin Compiler |
| JSR-330 (`javax.inject.*`)    | **Supported** — `@Inject`, `@Singleton`, `@Named`, `@Qualifier` |

## Gradle Changes

### Add Koin + Compiler Plugin (Step 3)

Add Koin per `references/gradle.md` — Compiler Plugin, `koin-bom`, only the artifacts the project needs (KMP: shared artifacts in `commonMain`, no per-target configuration). Versions: `references/rules.md` §3. Dagger stays in place.

### Remove Dagger — Step 8, after the last binding moved

```kotlin
// REMOVE from build.gradle.kts
plugins {
    // id("org.jetbrains.kotlin.kapt")  ← REMOVE if only used for Dagger
}

dependencies {
    // REMOVE:
    // implementation("com.google.dagger:dagger:2.x")
    // kapt("com.google.dagger:dagger-compiler:2.x")
    // OR
    // ksp("com.google.dagger:dagger-compiler:2.x")
}
```

## Component to Module

### Simple Component

```kotlin
// BEFORE: Dagger
@Singleton
@Component(modules = [NetworkModule::class, DatabaseModule::class])
interface AppComponent {
    fun inject(activity: MainActivity)
    fun inject(service: SyncService)

    @Component.Factory
    interface Factory {
        fun create(@BindsInstance context: Context): AppComponent
    }
}
```

```kotlin
// AFTER: Koin — the component becomes a root module, discovered at start
@Module(includes = [NetworkModule::class, DatabaseModule::class])
@Configuration
@ComponentScan("com.myapp.app")          // focused package (references/rules.md §7)
class AppModule

@KoinApplication
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin<App> { androidContext(this@App) }   // no modules(...) — discovered
    }
}
```

### Module with @Provides

```kotlin
// BEFORE: Dagger
@Module
class NetworkModule {
    @Provides @Singleton
    fun provideOkHttp(): OkHttpClient = OkHttpClient.Builder().build()

    @Provides @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit =
        Retrofit.Builder().client(client).baseUrl(URL).build()
}
```

```kotlin
// AFTER: Koin @Module with annotated functions
@Module
class NetworkModule {
    @Singleton
    fun provideOkHttp(): OkHttpClient = OkHttpClient.Builder().build()

    @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit =
        Retrofit.Builder().client(client).baseUrl(URL).build()
}
```

### Module with @Binds

```kotlin
// BEFORE: Dagger
@Module
abstract class RepositoryModule {
    @Binds @Singleton
    abstract fun bindRepo(impl: RepoImpl): Repo
}
```

```kotlin
// AFTER: Koin — annotate the implementation directly
@Singleton
class RepoImpl(
    private val api: ApiService,
    private val dao: UserDao
) : Repo
// Auto-bind: the compiler binds Repo, the interface it implements
```

## Subcomponents to Scopes

Dagger subcomponents model a lifecycle hierarchy. In Koin: the scope archetype when the
subcomponent follows an Activity, Fragment or ViewModel, otherwise a custom `@Scope`
("Choose the scope" in `references/scopes.md`). A session subcomponent → a custom scope:

```kotlin
// BEFORE: Dagger
@Subcomponent(modules = [SessionModule::class])
@SessionScope
interface SessionComponent {
    fun inject(fragment: DashboardFragment)

    @Subcomponent.Factory
    interface Factory {
        fun create(): SessionComponent
    }
}

// Parent component exposes factory
@Component(...)
interface AppComponent {
    fun sessionComponentFactory(): SessionComponent.Factory
}
```

```kotlin
// AFTER: Koin
class SessionScopeId  // Scope marker

@Scope(SessionScopeId::class)
@Scoped
class SessionManager(private val api: ApiService)

@Scope(SessionScopeId::class)
@Scoped
class DashboardRepository(private val api: ApiService, private val db: AppDatabase)

// Open scope when session starts
val sessionScope = getKoin().createScope<SessionScopeId>("user_session")

// Inject from scope
val manager = sessionScope.get<SessionManager>()

// Close when session ends
sessionScope.close()
```

A `@Subcomponent.Factory` that takes arguments (`create(@BindsInstance userId: String)`)
→ declare them into the scope as it opens, and give the scope one owner that
closes the previous one: "Scope with a runtime value" in `references/scopes.md`.

## Injection Patterns

### Field Injection → Koin Delegate

```kotlin
// BEFORE: Dagger field injection
class MyActivity : AppCompatActivity() {
    @Inject lateinit var analytics: Analytics
    @Inject lateinit var logger: Logger

    override fun onCreate(savedInstanceState: Bundle?) {
        (application as App).appComponent.inject(this)
        super.onCreate(savedInstanceState)
    }
}
```

```kotlin
// AFTER: Koin
class MyActivity : AppCompatActivity() {
    private val analytics: Analytics by inject()
    private val logger: Logger by inject()

    // No manual injection call needed
}
```

### Constructor Injection

```kotlin
// BEFORE: Dagger
class UserRepository @Inject constructor(
    private val api: ApiService,
    private val db: UserDao
)
```

```kotlin
// AFTER: Koin — @Inject maps to @Factory (new instance per injection)
@Factory
class UserRepository(
    private val api: ApiService,
    private val db: UserDao
)
// Constructor parameters auto-resolved at compile time.
// Use @Singleton if the Dagger class was also @Singleton scoped.
```

## Qualifiers

Custom `@Qualifier` annotations from Dagger can be **reused as-is** with the Koin Compiler.

```kotlin
// BEFORE: Dagger — these custom qualifiers work with Koin Compiler unchanged
@Qualifier
@Retention(AnnotationRetention.RUNTIME)
annotation class IoDispatcher

@Module
object DispatcherModule {
    @Provides @IoDispatcher
    fun provideIoDispatcher(): CoroutineDispatcher = Dispatchers.IO

    @Provides @MainDispatcher
    fun provideMainDispatcher(): CoroutineDispatcher = Dispatchers.Main
}

class MyRepo @Inject constructor(
    @IoDispatcher private val dispatcher: CoroutineDispatcher
)
```

```kotlin
// AFTER: Koin — using @Named
@Module
class DispatcherModule {
    @Singleton
    @Named("io")
    fun provideIoDispatcher(): CoroutineDispatcher = Dispatchers.IO

    @Singleton
    @Named("main")
    fun provideMainDispatcher(): CoroutineDispatcher = Dispatchers.Main
}

@Factory   // unscoped @Inject constructor → @Factory
class MyRepo(@Named("io") private val dispatcher: CoroutineDispatcher)
```

Or with custom type-safe qualifiers:
```kotlin
@Qualifier
@Retention(AnnotationRetention.RUNTIME)
annotation class IoDispatcher

@Module
class DispatcherModule {
    @Singleton @IoDispatcher
    fun provideIo(): CoroutineDispatcher = Dispatchers.IO
}

@Factory
class MyRepo(@IoDispatcher private val dispatcher: CoroutineDispatcher)
```

## Multibindings

Koin has no Set / Map multibinding. One pattern for every source: each element
is its own definition bound to `T`, with a distinct `@Named` (without it each
element overrides the previous `T` binding — a startup warning, an error with
`allowOverride(false)`). Consumers inject `List<T>`: every definition of `T`,
empty when there is none.

| Source | Koin |
|---|---|
| `@IntoSet` / `@ContributesIntoSet` element | `@Singleton` / `@Factory` + `@Named("<element>")` on the class, auto-bound to `T` |
| `@ElementsIntoSet` (several at once) | One definition per element, as above |
| `Set<T>` consumer | `List<T>` parameter (`.toSet()` if a `Set` is needed) |
| `@IntoMap` + `@StringKey` / `@ClassKey` (not a ViewModel) | Elements as above; consumer `List<T>` + `associateBy { it.key }` (`T` exposes its key). Key not on `T` → one `@Module` function taking the named elements, returning the `Map` |
| `@IntoMap @ViewModelKey` | `@KoinViewModel` — below |
| `@Multibinds` (declared, maybe empty) | Deleted — `List<T>` is empty when no element |

### Set multibinding

```kotlin
// BEFORE: Dagger
@Module
abstract class PluginModule {
    @Binds @IntoSet
    abstract fun bindA(a: PluginA): Plugin

    @Binds @IntoSet
    abstract fun bindB(b: PluginB): Plugin
}
```

```kotlin
// AFTER: Koin — each element bound to Plugin, consumers take List<Plugin>
@Singleton @Named("pluginA")
class PluginA : Plugin { /* ... */ }

@Singleton @Named("pluginB")
class PluginB : Plugin { /* ... */ }

@Singleton
class PluginRegistry(private val plugins: List<Plugin>)   // was Set<Plugin>
```

### Map multibinding (ViewModel factory pattern)

```kotlin
// BEFORE: Dagger
@Module
abstract class ViewModelModule {
    @Binds @IntoMap
    @ViewModelKey(HomeViewModel::class)
    abstract fun bindHome(vm: HomeViewModel): ViewModel
}
```

```kotlin
// AFTER: Koin — just annotate each ViewModel directly
@KoinViewModel
class HomeViewModel(private val repo: HomeRepository) : ViewModel()

@KoinViewModel
class DetailViewModel(private val repo: DetailRepository) : ViewModel()
// No map needed — Koin resolves by type
```

## Component Dependencies

```kotlin
// BEFORE: Dagger — component depends on another
@Component(dependencies = [NetworkComponent::class])
interface FeatureComponent {
    fun inject(activity: FeatureActivity)
}
```

```kotlin
// AFTER: Koin — module includes
@Module(includes = [NetworkModule::class])
@ComponentScan("com.myapp.feature")
class FeatureModule
```

## Custom Scopes

```kotlin
// BEFORE: Dagger
@Scope
@Retention(AnnotationRetention.RUNTIME)
annotation class ActivityScope

@ActivityScope
@Subcomponent
interface ActivitySubcomponent { ... }
```

AFTER: `@ActivityScope` (or `@Scope` + `@Scoped`) and `AndroidScopeComponent` in the Activity — `references/scopes.md`.

## Parameter Resolution

Constructor and function parameters (`T`, `T?`, `Lazy<T>`, `List<T>`, `@InjectedParam`, qualifiers, properties) are resolved by the Compiler Plugin — see "Parameter resolution" in `references/koin-compiler-plugin-dsl.md` and "Parameters & qualifiers" in `references/koin-annotations.md`.

## Lazy and Provider

```kotlin
// BEFORE: Dagger
class MyClass @Inject constructor(
    private val lazyService: Lazy<HeavyService>,     // dagger.Lazy
    private val providerService: Provider<LightService>  // javax.inject.Provider
)
```

```kotlin
// AFTER: Koin — unscoped @Inject constructor → @Factory
@Factory
class MyClass(
    private val lazyService: Lazy<HeavyService>,   // kotlin.Lazy — resolved on first access
    private val scope: Scope                        // org.koin.core.scope.Scope — passed as-is
) {
    fun work() = scope.get<LightService>().run()   // fresh instance per call (@Factory LightService)
}
```

The Compiler Plugin resolves `Lazy<T>`, `List<T>`, `T?` and `Scope` parameters —
not `() -> T` or `Provider<T>`. `Provider<T>` used to defer creation → `Lazy<T>` (the default);
used for a fresh instance per call → `@Factory` on the type and `scope.get<T>()`
at the use site. That second form is a **service locator** in a normal class:
the dependency isn't compile-checked — state the cost and get the user's OK
first (`references/rules.md` §8).
