# Koin DSL → Koin 4.x Compiler Plugin DSL Migration Reference

> **Setup & versions** — Gradle: `references/gradle.md` · versions: `references/rules.md` §3 · exact syntax: `references/koin-annotations.md` / `references/koin-compiler-plugin-dsl.md`.

## Table of Contents
1. [Progressive Migration](#progressive-migration)
2. [Why Convert (optional)](#why-convert-optional)
3. [Core DSL Mapping](#core-dsl-mapping)
4. [Gradle Setup](#gradle-setup)
5. [Singleton and Factory](#singleton-and-factory)
6. [ViewModel](#viewmodel)
7. [Qualifiers and Named](#qualifiers-and-named)
8. [Scopes](#scopes)
9. [Bindings (Interface → Implementation)](#bindings)
10. [Parameters](#parameters)
11. [Module Composition](#module-composition)
12. [KMP Modules](#kmp-modules)
13. [Compose Integration](#compose-integration)
14. [Mixing Old and New DSL](#mixing-old-and-new-dsl)
15. [Compile-Time Safety](#compile-time-safety)
16. [Common Pitfalls](#common-pitfalls)

---

## Progressive Migration

1. **Whole project, once (Step 3)** — Compiler Plugin + BOM. Every DSL form —
   Classic, Constructor, Compiler Plugin DSL — is now compile checked
   (`references/rules.md` §6). This is the compile-safety step; the project can
   stop here, in its current form.
2. **Optional, module by module (loop)** — on the user's choice, convert each
   module's definitions to Compiler Plugin DSL, validated before the next. Old
   and new forms coexist meanwhile ("Mixing Old and New DSL").

Nothing is rewritten in place in one pass.

## Why Convert (optional)

Adding the Compiler Plugin already checks every form. Converting to the
**Compiler Plugin DSL** (`single<T>()`, `factory<T>()`) is a style choice:

- **No manual `get()` wiring** — constructor parameters resolved from `single<T>()`
- **Cycle detection through constructors** — a cycle between definitions is reported at build time
- **Same module structure** — `val myModule = module { }` stays, only the definitions change

Default: keep the project's current form; mention conversion as an option.

Versions: `references/rules.md` §3.

## Core DSL Mapping

| Old Koin DSL (3.x / 4.x manual)                    | New Compiler Plugin DSL                                             |
|-----------------------------------------------------|------------------------------------------------------|
| `single { MyClass(get()) }`                         | `single<MyClass>()`                                  |
| `single { MyClass(get(), get()) }`                  | `single<MyClass>()`                                  |
| `singleOf(::MyClass)`                               | `single<MyClass>()`                                  |
| `factory { MyClass(get()) }`                        | `factory<MyClass>()`                                 |
| `factoryOf(::MyClass)`                              | `factory<MyClass>()`                                 |
| `viewModel { MyVM(get()) }`                         | `viewModel<MyVM>()`                                  |
| `viewModelOf(::MyVM)`                               | `viewModel<MyVM>()`                                  |
| `scoped { MyClass(get()) }`                         | `scoped<MyClass>()`                                  |
| `scopedOf(::MyClass)`                               | `scoped<MyClass>()`                                  |
| `worker { MyWorker(get(), get(), get()) }`          | `worker<MyWorker>()`                                 |
| `singleOf(::Impl) { bind<Interface>() }`            | `single<Impl>().withOptions { bind<Interface>() }`   |
| `singleOf(::Impl) { named("x") }`                  | `@Named("x")` on the class + `single<Impl>()`        |
| `singleOf(::Impl) { createdAtStart() }`             | `single<Impl>().withOptions { createdAtStart() }`    |
| `single(named("x")) { Dispatchers.IO }`            | `single(named("x")) { Dispatchers.IO }` (unchanged for lambdas with custom logic) |
| `module { includes(other) }`                        | `module { includes(other) }` (unchanged)              |

**Key principle**: `single<T>()` with a reified type parameter tells the compiler plugin
to resolve `T`'s constructor parameters from the DI graph. No `get()` calls needed.

**Note**: `single(::T)` constructor reference syntax is NOT supported. Use `single<T>()`.

## Gradle Setup

### Before (Koin 3.x / manual DSL)

```kotlin
dependencies {
    implementation("io.insert-koin:koin-core:3.5.x")
    implementation("io.insert-koin:koin-android:3.5.x")
    implementation("io.insert-koin:koin-androidx-compose:3.5.x")
}
```

### After (Koin 4.x + Compiler Plugin)

Add Koin per `references/gradle.md` — Compiler Plugin, `koin-bom`, only the artifacts the project needs (KMP: shared artifacts in `commonMain`, no per-target configuration). Versions: `references/rules.md` §3.


## Singleton and Factory

### Singleton

```kotlin
// BEFORE: Old DSL
val dataModule = module {
    single { AppDatabase.create(androidContext()) }
    single { get<AppDatabase>().userDao() }
    singleOf(::UserRepository)
}
```

```kotlin
// AFTER: Compiler Plugin DSL
fun buildDatabase(context: Context): AppDatabase = AppDatabase.create(context)
fun buildUserDao(db: AppDatabase): UserDao = db.userDao()

val dataModule = module {
    // Custom creation logic — function builders (references/rules.md §1)
    single { create(::buildDatabase) }
    single { create(::buildUserDao) }

    // Classes you own with standard constructors — use reified type
    single<UserRepository>()
    // Compiler resolves: UserRepository(get<ApiService>(), get<UserDao>())
}
```

### Factory

```kotlin
// BEFORE: Old DSL
val presenterModule = module {
    factory { DetailPresenter(get(), get()) }
    factoryOf(::ListPresenter)
}
```

```kotlin
// AFTER: Compiler Plugin DSL
val presenterModule = module {
    factory<DetailPresenter>()
    factory<ListPresenter>()
}
```

### Created at start

```kotlin
// BEFORE: Old DSL
val appModule = module {
    single(createdAtStart = true) { AnalyticsInitializer(get()) }
}
```

```kotlin
// AFTER: Compiler Plugin DSL
val appModule = module {
    single<AnalyticsInitializer>().withOptions { createdAtStart() }
}
```

## ViewModel

```kotlin
// BEFORE: Old DSL
val viewModelModule = module {
    viewModelOf(::MainViewModel)
    viewModel { DetailViewModel(get(), get()) }
    viewModel { SavedStateViewModel(get(), get()) }
}
```

```kotlin
// AFTER: Compiler Plugin DSL
val viewModelModule = module {
    viewModel<MainViewModel>()
    viewModel<DetailViewModel>()
    viewModel<SavedStateViewModel>()
    // SavedStateHandle is auto-resolved by Koin — no special config needed
}
```

Usage remains the same:
```kotlin
// Activity/Fragment
private val viewModel: MainViewModel by viewModel()

// Compose
val viewModel = koinViewModel<MainViewModel>()
```

### ViewModel with runtime parameters

```kotlin
// BEFORE: Old DSL
val viewModelModule = module {
    viewModel { params -> PlayerViewModel(get(), params.get()) }
}
```

```kotlin
// AFTER: Compiler Plugin DSL — parameters still work the same way
val viewModelModule = module {
    viewModel<PlayerViewModel>()
    // The compiler knows which params come from DI and which from parametersOf()
    // based on @InjectedParam annotation on the ViewModel constructor
}

// The ViewModel class needs @InjectedParam on the runtime parameter:
class PlayerViewModel(
    private val repo: PlayerRepository,
    @InjectedParam private val playerId: String  // Comes from parametersOf()
) : ViewModel()

// Usage:
val viewModel: PlayerViewModel by viewModel { parametersOf("player_123") }
```

## Qualifiers and Named

### Named qualifier

```kotlin
// BEFORE: Old DSL
val dispatcherModule = module {
    single(named("io")) { Dispatchers.IO as CoroutineDispatcher }
    single(named("main")) { Dispatchers.Main as CoroutineDispatcher }
}

val repoModule = module {
    single { MyRepo(get(named("io"))) }
}
```

```kotlin
// AFTER: Compiler Plugin DSL
val dispatcherModule = module {
    // Lambda syntax for inline values (no constructor to resolve)
    single(named("io")) { Dispatchers.IO as CoroutineDispatcher }
    single(named("main")) { Dispatchers.Main as CoroutineDispatcher }
}

val repoModule = module {
    // Plain reified type — the qualifier lives on MyRepo's constructor param
    single<MyRepo>()
}

// MyRepo class — @Named on the constructor param tells the compiler which qualifier to use
class MyRepo(
    @Named("io") private val dispatcher: CoroutineDispatcher
)
```

### Enum qualifiers (new in 4.x)

```kotlin
enum class DispatcherType { IO, Main, Default }

val dispatcherModule = module {
    single(named(DispatcherType.IO)) { Dispatchers.IO as CoroutineDispatcher }
    single(named(DispatcherType.Main)) { Dispatchers.Main as CoroutineDispatcher }
}
```

## Scopes

### Android Scope Archetypes

Try an archetype first (`activityScope { }`, `fragmentScope { }`, `viewModelScope { }`) — "Choose the scope" in `references/scopes.md`.

### Custom scopes — when no archetype fits

```kotlin
// BEFORE: Old DSL
val sessionModule = module {
    scope<UserSession> {
        scoped { SessionManager(get()) }
        scoped { UserPreferences(get()) }
    }
}
```

```kotlin
// AFTER: Compiler Plugin DSL
val sessionModule = module {
    scope<UserSession> {
        scoped<SessionManager>()
        scoped<UserPreferences>()
    }
}
```

Scope lifecycle management remains the same:
```kotlin
val scope = getKoin().createScope<UserSession>("session_id")
val manager = scope.get<SessionManager>()
scope.close()
```

## Bindings

### Single interface binding

```kotlin
// BEFORE: Old DSL
val repoModule = module {
    singleOf(::UserRepositoryImpl) { bind<UserRepository>() }
}
```

```kotlin
// AFTER: Compiler Plugin DSL
val repoModule = module {
    single<UserRepositoryImpl>().withOptions { bind<UserRepository>() }
}
```

### Multiple interface bindings

```kotlin
// BEFORE: Old DSL
val module = module {
    single { ServiceImpl(get()) } bind ServiceA::class bind ServiceB::class
}
```

```kotlin
// AFTER: Compiler Plugin DSL
val module = module {
    single<ServiceImpl>().withOptions {
        bind<ServiceA>()
        bind<ServiceB>()
    }
}
```

## Parameters

### Runtime parameters

For classes that need runtime values (not from the DI graph), mark them with `@InjectedParam`:

```kotlin
// The class:
class Notification(
    @InjectedParam private val title: String,
    private val sender: NotificationSender
)

// BEFORE: Old DSL
val module = module {
    factory { params -> Notification(params.get(), get()) }
}

// AFTER: Compiler Plugin DSL
val module = module {
    factory<Notification>()
}
// Usage: get<Notification> { parametersOf("title") }
```

`@InjectedParam` and `@Named` / `@Qualifier` are the only annotations needed on classes in the
Compiler Plugin DSL approach. `@InjectedParam` tells the compiler "this parameter comes from
`parametersOf()`, not from the graph."

### Nullable dependencies

```kotlin
class MyService(
    private val required: RequiredDep,
    private val optional: OptionalDep?  // Nullable — compiler uses getOrNull()
)

val module = module {
    single<MyService>()  // Compiler: MyService(get(), getOrNull())
}
```

### Parameters with default values

```kotlin
class MyService(
    private val required: RequiredDep,
    private val timeout: Int = 30  // Default value — skipped by compiler (when skipDefaultValues=true)
)

val module = module {
    single<MyService>()  // Compiler: MyService(get()) — uses Kotlin default for timeout
}
```

## Module Composition

Module composition stays the same — just update the inner declarations:

```kotlin
// BEFORE: Old DSL
val networkModule = module {
    single { OkHttpClient.Builder().build() }
    single { Retrofit.Builder().client(get()).baseUrl(URL).build() }
    single { get<Retrofit>().create(ApiService::class.java) }
}

val repositoryModule = module {
    singleOf(::UserRepository)
}

val appModule = module {
    includes(networkModule, repositoryModule)
}

startKoin {
    androidContext(this@App)
    modules(appModule)
}
```

```kotlin
// AFTER: Compiler Plugin DSL — third-party types through function builders
fun buildOkHttp(): OkHttpClient = OkHttpClient.Builder().build()
fun buildRetrofit(client: OkHttpClient): Retrofit = Retrofit.Builder().client(client).baseUrl(URL).build()
fun buildApi(retrofit: Retrofit): ApiService = retrofit.create(ApiService::class.java)

val networkModule = module {
    single { create(::buildOkHttp) }
    single { create(::buildRetrofit) }
    single { create(::buildApi) }
}

val repositoryModule = module {
    single<UserRepository>()  // Reified — compiler resolves constructor
}

val appModule = module {
    includes(networkModule, repositoryModule)
}

startKoin {
    androidContext(this@App)
    modules(appModule)
}
```

Which form for which definition: `references/rules.md` §1 (plain constructor →
`single<T>()`; third-party / custom expression → function builder, lambda as a
last resort). All forms are checked by the Compiler Plugin.

## KMP Modules

Same Compiler Plugin DSL on every target; common and platform modules with `expect` / `actual`: `references/rules.md` §7.

## Compose Integration

No change on the Compose side — the modules change, not the call sites (`references/entry-points.md`).

## Mixing Old and New DSL

Conversion can be incremental. Old and new DSL syntax coexist in the same module:

```kotlin
val myModule = module {
    // Converted — Compiler Plugin DSL
    single<UserRepository>()
    factory<DetailPresenter>()
    viewModel<MainViewModel>()

    // Not yet converted — Classic DSL, compile checked too
    single { OkHttpClient.Builder().build() }
    single { Retrofit.Builder().client(get()).baseUrl(URL).build() }
}
```

Conversion order, when the user chose to convert:
1. Start with leaf classes (simple constructors, no custom logic)
2. Move to ViewModels
3. Then repositories and data layer
4. Third-party types and builders → function builder `single { create(::buildX) }`
   (`references/rules.md` §1); classic lambda only for a custom expression — it's
   compile-checked too

## Parameter Resolution

All constructor and function parameters are **handled automatically by the Koin Compiler**:
`T`, `T?`, `Lazy<T>`, `List<T>` — just declare the type, the compiler does the rest.

Use `@InjectedParam` for runtime values, `@Named("x")` for qualified dependencies.
Parameters with default values are skipped (uses Kotlin default).

```kotlin
// All parameter types handled by the Koin Compiler:
class MyService(
    private val api: ApiService,              // T — required
    private val logger: Logger?,              // T? — optional
    private val heavyDep: Lazy<HeavyService>, // Lazy<T> — deferred
    private val plugins: List<Plugin>,        // List<T> — all matching
    @Named("io") private val dispatcher: CoroutineDispatcher,  // qualified
    private val timeout: Int = 30             // default value — skipped
)

val module = module {
    single<MyService>()  // Compiler handles all the wiring
}
```

## Compile-Time Safety

The Compiler Plugin checks every DSL form, Classic included (`references/rules.md` §6).

### What gets validated

| Scenario                                   | Result                                          |
|--------------------------------------------|-------------------------------------------------|
| Non-nullable param, no definition          | **ERROR** at compile time                       |
| Nullable param (`T?`), no definition       | OK — uses `getOrNull()`                         |
| Param with default value, no definition    | OK — uses Kotlin default (when `skipDefaultValues=true`) |
| `@InjectedParam`, no definition            | OK — provided at runtime via `parametersOf()`   |
| `Lazy<T>`, no definition for T            | **ERROR** — validates inner type                |
| `@Named("x")` param, no matching qualifier | **ERROR** — with hint if unqualified exists     |
| Scoped dependency from wrong scope         | **ERROR**                                       |

### Error messages

Missing dependencies are Kotlin compiler errors with a `[KOIN-…]` code:

```
e: [Koin][KOIN-D001] Missing dependency: com.acme.ApiService
  required by: com.acme.UserRepository (parameter 'api')
  in module: com.acme.dataModule
```

### Runtime verification

Not needed: the compile-time check replaces it. `checkModules()` and `verify()`
are on their way to deprecation — remove existing ones once the Compiler Plugin
is in place.

## Common Pitfalls

### 1. Using constructor reference syntax instead of reified type

```kotlin
// WRONG — constructor reference syntax is NOT supported by the compiler plugin
val module = module {
    single(::MyService)  // not supported
}

// RIGHT — use reified type parameter
val module = module {
    single<MyService>()
}
```

### 2. Forgetting @InjectedParam on runtime parameters

```kotlin
// WRONG — compiler treats `itemId` as a dependency to resolve from the graph
class DetailViewModel(
    private val repo: ItemRepository,
    private val itemId: String  // Will fail: no String binding in graph
) : ViewModel()

// RIGHT — mark runtime params with @InjectedParam
class DetailViewModel(
    private val repo: ItemRepository,
    @InjectedParam private val itemId: String  // Comes from parametersOf()
) : ViewModel()
```

### 3. Using reified type for third-party classes with no public constructor

```kotlin
// WRONG — Retrofit has no public constructor the compiler can resolve
val module = module {
    single<Retrofit>()  // Compiler error: can't resolve constructor
}

// RIGHT — a function builder (the compiler checks its parameters)
fun buildRetrofit(client: OkHttpClient): Retrofit = Retrofit.Builder().client(client).baseUrl(URL).build()
val module = module {
    single { create(::buildRetrofit) }
}
```

### 4. Forgetting the compiler plugin in build.gradle.kts

Without `id("io.insert-koin.compiler.plugin")`, Compiler Plugin DSL code (`single<T>()`,
`create(::T)`, `startKoin<App>`…) compiles but **fails at runtime** with
`NotImplementedError` — they need the plugin. Apply the plugin in every Gradle module that declares Koin definitions
(`references/gradle.md`).

### 5. ViewModel declared in its own scope without the scope factory

`viewModel<T>()` inside `viewModelScope { }` is valid — it needs
`options(viewModelScopeFactory())` at start (`references/scopes.md`):

```kotlin
val module = module {
    viewModelScope {
        scoped<SessionCache>()
        viewModel<SessionViewModel>()
    }
}

startKoin {
    options(viewModelScopeFactory())
    modules(module)
}
```

### 6. Missing qualification on same-type params

```kotlin
// WRONG — two CoroutineDispatcher params, compiler can't distinguish
class MyRepo(
    private val ioDispatcher: CoroutineDispatcher,
    private val mainDispatcher: CoroutineDispatcher
)

// RIGHT — use @Named to distinguish same-type params
class MyRepo(
    @Named("io") private val ioDispatcher: CoroutineDispatcher,
    @Named("main") private val mainDispatcher: CoroutineDispatcher
)
```
