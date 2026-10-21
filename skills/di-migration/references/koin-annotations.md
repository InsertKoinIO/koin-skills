# Koin Annotations + Compiler Plugin — Reference

Concrete cheat sheet for **Koin Annotations + Compiler Plugin** code. Shared by every Koin skill (setup, core, migration, diagnose) — exact imports and syntax live here; don't infer them from memory.

For depth, see https://insert-koin.io.

## Setup

Gradle and versions: `references/gradle.md`. Policy (style choice, configuration): `references/rules.md`.

**JSR-330 support**: the Koin Compiler also handles `jakarta.inject.*` and
`javax.inject.*` directly — `@Inject`, `@Singleton`, `@Named`, `@Qualifier`
all work as-is. Custom `@Qualifier` annotations from Dagger / Hilt / Toothpick
can be **reused without changes** in Koin annotation output.

## Imports — lookup table

| Symbol                                                                                              | Import                                                | Notes                                                            |
|-----------------------------------------------------------------------------------------------------|-------------------------------------------------------|------------------------------------------------------------------|
| `@Module`, `@Configuration`, `@ComponentScan`                                                       | `org.koin.core.annotation.*`                          | Module declaration triad                                         |
| `@Singleton`, `@Single`, `@Factory`, `@KoinViewModel`, `@KoinWorker`                                | `org.koin.core.annotation.*`                          | Binding annotations                                              |
| `@KoinApplication`                                                                                  | `org.koin.core.annotation.*`                          | Application entry point                                          |
| `@InjectedParam`, `@Named`, `@Property`, `@Qualifier`                                               | `org.koin.core.annotation.*`                          | Parameter / qualifier annotations                                |
| `@Scope`, `@Scoped`                                                                                 | `org.koin.core.annotation.*`                          | Custom scope annotations                                         |
| `@ActivityScope`, `@ActivityRetainedScope`, `@FragmentScope`, `@ViewModelScope`                     | `org.koin.core.annotation.*`                          | Android scope archetypes                                         |
| `startKoin<App>`, `koinApplication<App>`, `koinConfiguration<App>`                                  | `org.koin.plugin.module.dsl.*`                        | **Compiler-Plugin entry points** — reified, trigger auto-discovery. NOT `org.koin.core.context.startKoin` |
| `KoinApplication.module<T>()`, `KoinApplication.modules(vararg KClass)`                             | `org.koin.plugin.module.dsl.*`                        | **Annotations-only escape hatch** — use when *not* relying on `@Configuration` auto-discovery (variant modules, conditional loading, test overrides). With `@Configuration` this is unnecessary. Not for Safe DSL output. |
| `koinViewModel()`                                                                                   | `org.koin.compose.viewmodel.koinViewModel`          | Compose ViewModel injection                                      |
| `koinInject()`                                                                                      | `org.koin.compose.koinInject`                         | Compose generic injection                                        |
| `androidContext`, `androidLogger`                                                                   | `org.koin.android.ext.koin.*`                         | Android startKoin DSL                                            |
| `workManagerFactory`                                                                                | `org.koin.androidx.workmanager.koin.workManagerFactory` | WorkManager startKoin DSL                                      |

**Avoid:** `org.koin.android.annotation.KoinViewModel` (legacy KSP location).
In Koin 4.x every annotation lives under `org.koin.core.annotation.*`.

## Bindings

| Annotation                          | Use for                                              |
|-------------------------------------|------------------------------------------------------|
| `@Singleton` (preferred)            | Shared instance for the whole graph (JSR-330 form)   |
| `@Single`                           | Same as `@Singleton`; emit `@Singleton` instead      |
| `@Factory`                          | New instance per resolution                          |
| `@KoinViewModel`                    | Android ViewModel (lifecycle-managed)                |
| `@KoinWorker`                       | WorkManager Worker (requires `koin-androidx-workmanager`) |
| `@Scoped`                           | Lifetime tied to a Koin scope (see Scopes)           |

```kotlin
@Singleton class HttpClient(val config: HttpConfig)
@Factory   class RequestId
@KoinViewModel class HomeViewModel(repo: Repository)
@KoinWorker class SyncWorker(ctx: Context, params: WorkerParameters, repo: Repo) : CoroutineWorker(ctx, params)
```

**Auto-bind**: when a `@Singleton` / `@Factory` class implements a single
interface, the binding is registered automatically — do not emit explicit
`bind`. Only set `binds` when the class implements multiple interfaces and
you want to expose a specific subset:

```kotlin
@Singleton class RepositoryImpl : Repository, Persistable
// → not auto-bound to either interface — explicit binds needed:
@Singleton(binds = [Repository::class]) class RepositoryImpl : Repository, Persistable
```

## Modules

| Annotation                                | Use for                                       |
|-------------------------------------------|-----------------------------------------------|
| `@Module`                                 | Marks a class as a Koin module                |
| `@Configuration`                          | Marks a module as a discovery root for `@KoinApplication` (not needed on modules pulled in via `includes`) |
| `@ComponentScan("com.example.pkg")`       | Auto-discover annotated classes in a package  |
| `@Module(includes = [Other::class])`      | Compose modules explicitly                    |

**The triad** (required for cross-module discovery in multi-Gradle-module projects):

```kotlin
@Module
@Configuration
@ComponentScan("com.acme.feature.foo")
class FooFeatureModule {
    @Singleton fun analytics(): Analytics = Analytics()  // third-party / factory function
}
```

Missing any of the three silently breaks discovery (no compile error, runtime
`NoDefinitionFoundException` at first injection).

**What `@Configuration` actually marks:** a **root** of a module subtree
discovered by `@KoinApplication`. Not every `@Module` class needs it — only
the ones you want `@KoinApplication` to pick up directly. Modules composed
via `@Module(includes = [...])` are pulled in transitively and **don't need
`@Configuration`**:

```kotlin
@Module                                // included module — @Configuration NOT needed
@ComponentScan("com.acme.api")
class ApiModule

@Module(includes = [ApiModule::class]) // pulls ApiModule into this subtree
@Configuration                         // root — discovered by @KoinApplication
@ComponentScan("com.acme.feature.foo")
class FooFeatureModule
```

Rule of thumb: **every Gradle module's top-level `@Module` class gets the full
triad.** Internal helper/sub-modules composed via `includes` need only `@Module`
(plus `@ComponentScan` if they own a package to scan).

## App entry point

```kotlin
import org.koin.plugin.module.dsl.startKoin

@KoinApplication
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin<App> {
            androidContext(this@App)
            // no modules(...) — Compiler Plugin auto-discovers triad-tagged modules
        }
    }
}
```

The reified `<App>` on `startKoin<T>()` is what triggers cross-module
auto-discovery. Without it (or with the classic `import org.koin.core.context.startKoin`),
the compiler plugin's discovery wiring is bypassed.

## Parameters & qualifiers

| Annotation                | Where applied                  | Replaces                              |
|---------------------------|--------------------------------|---------------------------------------|
| `@InjectedParam`          | Constructor param              | Runtime values via `parametersOf(...)` at call site |
| `@Named("auth")`          | Class or param                 | String qualifier                      |
| `@Qualifier`              | On your own annotation         | Custom type-safe qualifier            |
| `@Property("api.url")`    | Constructor param              | Inject Koin property value            |

```kotlin
@Qualifier annotation class Auth
@Singleton @Auth class AuthClient(@Property("api.url") val url: String) : HttpClient

@Factory class Connection(@InjectedParam val url: String)
// at call site: get<Connection> { parametersOf("https://...") }
```

## Scopes

| Annotation                              | Use for                                          |
|-----------------------------------------|--------------------------------------------------|
| `@Scope(MyScope::class)` + `@Scoped`    | Custom scope                                     |
| `@ActivityScope`                        | Tied to Android Activity lifecycle               |
| `@ActivityRetainedScope`                | Survives configuration changes                   |
| `@FragmentScope`                        | Tied to Fragment lifecycle                       |
| `@ViewModelScope`                       | Tied to ViewModel (cleared with VM)              |

```kotlin
@ActivityScope class TabRouter
@FragmentScope class FormState
@Scope(name = "session") @Scoped class SessionToken(@InjectedParam val userId: String)
```

## Retrieval

Entry points (Android, Compose, …): `references/entry-points.md`.

From inside another Koin-managed class — **don't use `KoinComponent`**, use
constructor injection. The compiler resolves every parameter:

```kotlin
@Singleton
class FeatureCoordinator(
    private val repo: Repository,
    private val analytics: Analytics,
    private val maybeFlag: FeatureFlag?,        // optional — null if no definition
    private val plugins: List<Plugin>,          // all definitions
    private val deferred: Lazy<HeavyService>    // resolved on first access
)
```

## Manual module retrieval (escape hatch)

```kotlin
import org.koin.plugin.module.dsl.module

startKoin {
    modules(module<MyModule>())   // reified helper — for conditional/test wiring
}
```

Default flow goes through `@KoinApplication` + `@Configuration` and never needs
this. Use only when you have variant-specific or test-only modules to inject
manually.

## Not covered here

- Safe DSL output — see `references/koin-safe-dsl.md`
- Multiplatform setup in depth — see https://insert-koin.io/docs/quickstart/kmp
- Property file loading, dynamic plugins, ktor integration — see https://insert-koin.io
