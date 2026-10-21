# Kodein → Koin 4.x + Koin Compiler Plugin Migration Reference

> **Setup & versions** — Gradle: `references/gradle.md` · versions: `references/rules.md` §3 · exact syntax: `references/koin-annotations.md` / `references/koin-compiler-plugin-dsl.md`.

## Table of Contents
1. [Progressive Migration](#progressive-migration)
2. [Concept Mapping](#concept-mapping)
3. [Gradle Setup](#gradle-setup)
4. [Module / DI Container](#module-container)
5. [Bindings](#bindings)
6. [Qualifiers / Tags](#qualifiers)
7. [Constructor Parameters](#constructor-parameters)
8. [Retrieval / Injection Sites](#retrieval)
9. [Android Integration](#android)
10. [Compose Integration](#compose)
11. [KMP Considerations](#kmp)
12. [Testing](#testing)

---

## Progressive Migration

Do **not** rewrite existing Kodein modules in place. Instead:

1. Set Koin up **alongside** the existing container — Step 3 (Gradle) and Step 5 (wiring) of the `di-migration` workflow
2. Keep the existing Kodein `DI` container running for everything not yet migrated
3. Move definitions from Kodein modules into the Koin module **one feature at a time**
4. At each call site, swap `by instance()` / `direct.instance()` for `by inject()` / `get()` only for the bindings already moved
5. Remove the Kodein dependency once the last binding has moved over (Step 8)

This keeps the project building and runnable at every step and limits the blast radius
of each migration commit.

Koin definitions read bindings still owned by Kodein through a
`Scope.kodein<T>()` helper, co-located in the consumer module —
`references/bridging.md`.

---

## Concept Mapping

Mappings target **Compiler Plugin DSL** (no annotations for Kodein):

| Kodein Construct                     | Koin Compiler Plugin DSL Equivalent                              |
|--------------------------------------|-------------------------------------------------------|
| `DI { ... }` container               | One app `module { includes(...) }` loaded by `startKoin { modules(appModule) }` |
| `DI.Module("name") { ... }`          | `val appModule = module { ... }`                      |
| `bind<T>() with singleton { ... }` / `bindSingleton<T> { }` | `single<T>()`                      |
| `bind<T>() with provider { ... }` / `bindProvider<T> { }`   | `factory<T>()`                     |
| `bindInstance<T> { ... }`            | `single { create(::buildT) }` (function builder); classic lambda only for a custom expression |
| `bind<T>() with scoped(scope).singleton { }` | `scope<S> { scoped<T>() }`                    |
| `bind<T>(tag = "x")`                 | `@Named("x")` on the class + `single<T>()` (reified) — always `@Named` for Kodein migrations |
| `instance()` / `by instance()`       | `get()` / `by inject()`                               |
| `factory<P, T>()` / `bindFactory<P, T> { }` (one runtime arg) | `@InjectedParam` on the param + `factory<T>()` — retrieve with `get { parametersOf(p) }` (destructuring lambda only for classes you can't annotate, `references/koin-compiler-plugin-dsl.md`) |
| `multiton<P, T>()` (cached factory)  | No direct equivalent — a `single<Map<P, T>>` cache, or `single<T>` per known key |
| `bindings.set { add(...) }` (set bindings) | Manual `List<T>` collected inside a `single<List<T>>` |
| `subDI(parentDI) { ... }`            | Child module included by the app module (`includes(child)`); a Koin scope if the child DI had its own lifetime (`references/scopes.md`) |
| `DIAware` interface on a class       | Constructor injection (see Retrieval below)          |
| `androidXModule(app)`                | `androidContext(this@App)` in `startKoin { }`         |
| `closestDI()` from Android `Context` | `getKoin()` (Android), `koinInject()` (Compose)       |

---

## Gradle Setup

Step 3 — add Koin per `references/gradle.md` — Compiler Plugin, `koin-bom`, only the artifacts the project needs (KMP: shared artifacts in `commonMain`, no per-target configuration). Versions: `references/rules.md` §3. Kodein stays in place.

Step 8, after the last binding moved — remove Kodein:

```kotlin
// REMOVE
implementation("org.kodein.di:kodein-di:<version>")
implementation("org.kodein.di:kodein-di-framework-android-x:<version>")
implementation("org.kodein.di:kodein-di-framework-compose:<version>")
```

---

## Module Container

**Kodein**

```kotlin
val appModule = DI.Module("app") {
    bind<Repository>() with singleton { RepositoryImpl(instance()) }
    bind<HttpClient>() with singleton { HttpClient() }
}

val di = DI {
    import(appModule)
}
```

**Koin (Compiler Plugin DSL — the default for Kodein migrations)**

Kodein's `DI { ... }` builder maps cleanly onto Koin's `module { }` lambda.
Compiler Plugin DSL keeps the same shape while adding reified type parameters and
compile-time verification via the Koin Compiler Plugin. **Do not produce an
annotations-based migration for Kodein** — there are no source annotations to
map from, and the DSL shape is what Kodein users are coming from.

```kotlin
val appModule = module {
    single<RepositoryImpl>().bind<Repository>()  // Compiler Plugin DSL, ctor auto-resolved
    single<HttpClient>()                         // Compiler Plugin DSL, no ctor params
    // viewModel<MyViewModel>()
    // factory<Connection>()
}

startKoin {
    modules(appModule)
}
```

Kodein migrations produce **Compiler Plugin DSL** — never `@Singleton` / `@Factory` /
`@Module` annotations. Definition forms (reified `single<T>()`, `.bind<I>()`,
function builders for third-party types, lambdas only for custom expressions):
`references/rules.md` §1 and `references/koin-compiler-plugin-dsl.md`.

---

## Bindings

| Kodein                                       | Koin Compiler Plugin DSL            |
|----------------------------------------------|--------------------------|
| `bind<T>() with singleton { T(instance()) }` | `single<T>()`            |
| `bind<T>() with provider { T() }`            | `factory<T>()`           |
| `bind<I>() with singleton { Impl() }`        | `single<Impl>().bind<I>()` (or `.withOptions { bind<I>() }`) |
| `bind<VM>() with provider { VM() }` (ViewModel) | `viewModel<VM>()`     |
| `bind<W>() with provider { W(...) }` (Worker) | `worker<W>()` — requires `io.insert-koin:koin-androidx-workmanager` |

---

## Qualifiers

**Kodein** uses `tag` to disambiguate:

```kotlin
bind<HttpClient>(tag = "auth") with singleton { HttpClient(authConfig) }
bind<HttpClient>(tag = "public") with singleton { HttpClient(publicConfig) }

val auth: HttpClient by instance(tag = "auth")
```

Kodein's `tag = "x"` maps to Koin's `@Named("x")`, placed on the class (or on
the consumer's constructor parameter), with a plain `single<T>()` in the module —
see "Qualifiers" in `references/koin-compiler-plugin-dsl.md`. `named("x")` stays only for
classic-DSL lambdas on types you can't annotate (`references/rules.md` §1).

**Stay on `@Named` for Kodein migrations** — don't introduce custom `@Qualifier`
annotations. Kodein's string-based `tag` semantics map 1:1 to `@Named`, and
keeping the string form preserves the shape Kodein users already recognize.

---

## Constructor Parameters

**Kodein** uses `factory<P, T>` for one runtime arg, `multiton` for caching:

```kotlin
bind<Connection>() with factory { url: String -> Connection(url) }

val conn: Connection = di.direct.factory<String, Connection>()("http://...")
```

**Koin** uses `@InjectedParam` and `parametersOf(...)`:

```kotlin
class Connection(@InjectedParam val url: String)

val connectionModule = module {
    factory<Connection>()
}

val conn: Connection = get { parametersOf("http://...") }
```

For multiple runtime args, list each `@InjectedParam` parameter — order matches `parametersOf(...)`.

---

## Retrieval

| Kodein                                  | Koin                            |
|-----------------------------------------|---------------------------------|
| `class X(override val di: DI) : DIAware` | Normal class → constructor injection. Android / framework entry point → its Koin API (`references/entry-points.md`). `KoinComponent` only with the user's OK (`references/rules.md` §8) |
| `val r: Repo by instance()`             | `val r: Repo by inject()`       |
| `val r: Repo = di.direct.instance()`    | `val r: Repo = get()`           |
| `val r: Repo by instance(tag = "x")`    | `val r: Repo by inject(named("x"))` |
| `val r: () -> Repo by provider()` (new instance per call when bound to `provider`) | `factory<Repo>()` + a `Scope` constructor parameter, `scope.get<Repo>()` on each call — a service locator, user's OK first (`references/rules.md` §8; "Lazy and Provider" in `references/dagger-to-koin.md`). `Lazy<Repo>` only matches Kodein `provider()` over a `singleton` binding — semantics differ for `provider` bindings. |
| `val r: Repo? by instanceOrNull()`      | `val r: Repo? by injectOrNull()` (or auto `Repo?` constructor param) |

Constructor injection everywhere else — `references/principles.md` rule 1–2.

---

## Android

**Kodein**

```kotlin
class App : Application(), DIAware {
    override val di by DI.lazy {
        import(androidXModule(this@App))
        import(appModule)
    }
}

class MyActivity : AppCompatActivity(), DIAware {
    override val di by closestDI()
    private val repo: Repository by instance()
}
```

**Koin**

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidContext(this@App)
            modules(appModule)            // one app module that includes the feature modules
        }
    }
}

class MyActivity : AppCompatActivity() {
    private val repo: Repository by inject()
    private val viewModel: MyViewModel by viewModel()
}
```

---

## Compose

**Kodein**

```kotlin
withDI(di) {
    val repo: Repository by rememberInstance()
}
```

**Koin**

```kotlin
@Composable
fun Screen() {
    val repo: Repository = koinInject()
    val vm: MyViewModel = koinViewModel()
}
```

---

## KMP

Kodein and Koin both support KMP. With the Koin Compiler Plugin:

- One plugin declaration in the root/shared module — no per-target configuration
- Use `expect`/`actual` for platform-specific bindings. Since Kodein migration
  output is Compiler Plugin DSL only, the typical split is either an `expect fun` / `actual
  fun` factory (shown below) or an `expect class` / `actual class` for the
  platform-specific implementation. Pick the smallest unit that varies per
  platform.
- Same `startKoin { }` entry point on every target

```kotlin
// commonMain
interface PlatformService

expect fun platformService(): PlatformService

val sharedModule = module {
    single { create(::platformService) }
}

// androidMain
actual fun platformService(): PlatformService = AndroidPlatformService()

// iosMain
actual fun platformService(): PlatformService = IosPlatformService()
```

---

## Testing

**Kodein**

```kotlin
val testDI = DI {
    import(appModule, allowOverride = true)
    bind<Repository>(overrides = true) with singleton { FakeRepository() }
}
```

**Koin**

```kotlin
@get:Rule
val koinTestRule = KoinTestRule.create {
    modules(appModule, module {
        single<FakeRepository>().bind<Repository>()  // overrides previous binding
    })
}
```

Graph verification: the **Koin Compiler Plugin** checks the full graph and the
resolution call sites at compile time, catching missing bindings. Don't add
`checkModules { }` / `verify()` — both are on their way to deprecation.
