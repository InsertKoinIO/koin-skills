# Koin Compiler Plugin DSL — Reference

Concrete cheat sheet for **Koin Compiler Plugin DSL** code. Shared by every Koin skill (setup, core, migration, diagnose) — exact imports and syntax live here; don't infer them from memory.

For depth, see https://insert-koin.io.

## Setup

Gradle and versions: `references/gradle.md`. Policy (style choice, DSL forms, configuration): `references/rules.md`.

## Imports

**The Compiler Plugin DSL lives in a single package** —
`org.koin.plugin.module.dsl`. One import covers most of the surface.

| Symbol                                                                                              | Import                                       | Notes                                                          |
|-----------------------------------------------------------------------------------------------------|----------------------------------------------|----------------------------------------------------------------|
| `single<T>()`, `factory<T>()` (on `Module`)                                                         | `org.koin.plugin.module.dsl.*`               | **Compiler Plugin DSL — reified, no lambda. Compiler resolves ctor.**     |
| `scoped<T>()`, `factory<T>()` (on `ScopeDSL`)                                                       | `org.koin.plugin.module.dsl.*`               | Scope-bound reified definitions                                |
| `viewModel<T>()`                                                                                    | `org.koin.plugin.module.dsl.*`               | From `koin-core-viewmodel`                                     |
| `worker<T>()`                                                                                       | `org.koin.plugin.module.dsl.*`               | From `koin-androidx-workmanager`                               |
| `Scope.create(::T)`                                                                                 | `org.koin.plugin.module.dsl.create`          | Explicit factory-function reference (alternative to `single<T>()`) |
| `module { }` (builder lambda)                                                                       | `org.koin.dsl.module`                        | Module declaration block                                       |
| `startKoin { modules(...) }`                                                                        | `org.koin.core.context.startKoin`            | **Classic startKoin — use this for Compiler Plugin DSL output.** The reified `startKoin<App>()` from `org.koin.plugin.module.dsl` is for `@KoinApplication` (annotations path) only. |
| `bind I::class` (infix), `.bind<T>()` on `KoinDefinition<*>`                                        | `org.koin.dsl.bind`                          | Interface binding — infix by default                           |
| `.withOptions { ... }`                                                                              | `org.koin.core.module.dsl.withOptions`       | Combine binding with other options                             |
| `bind<T>()` inside `withOptions { }`                                                                | `org.koin.core.module.dsl.bind`              | The `BeanDefinition` form                                      |
| `singleOf(::T)`, `factoryOf(::T)`, `viewModelOf(::T)`                                               | `org.koin.core.module.dsl.*`                 | **Constructor DSL — supported, not for new code. Prefer `single<T>()`**  |
| `named("x")`, `qualifier<T>()`, `Qualifier`                                                         | `org.koin.core.qualifier.*`                  | String qualifier; `qualifier<Auth>()` = the custom `@Auth` qualifier |
| `parametersOf(...)`                                                                                 | `org.koin.core.parameter.parametersOf`       | Pass runtime params at retrieval                               |
| `androidContext`, `androidLogger`                                                                   | `org.koin.android.ext.koin.*`                | Android startKoin DSL                                          |
| `koinInject()`                                                                       | `org.koin.compose.*`                         | Compose injection                                              |
| `koinViewModel()` (Compose retrieval)                                                               | `org.koin.compose.viewmodel.koinViewModel` | Compose ViewModel                                              |
| `workManagerFactory()` (startKoin DSL)                                                              | `org.koin.androidx.workmanager.koin.workManagerFactory` | WorkManager startKoin setup                       |
| `KoinComponent`, `inject()`, `get()`                                                                | `org.koin.core.component.*`                  | For classes Koin doesn't construct — prefer constructor injection |

## Definitions — form preference

For classes you own, always use the **reified** form. The Koin Compiler Plugin
resolves every constructor parameter automatically — no lambda needed.

| Form                              | Use when                                           |
|-----------------------------------|----------------------------------------------------|
| `single<T>()`                     | Shared instance, class you own                     |
| `factory<T>()`                    | New instance per resolution, class you own         |
| `viewModel<T>()`                  | Android ViewModel, class you own                   |
| `worker<T>()`                     | WorkManager Worker — reified Compiler Plugin DSL form (needs `koin-androidx-workmanager`) |
| `single { create(::T) }`          | Explicit factory-function reference — equivalent to `single<T>()`, use when intent should be visible in review |
| `single { create(::buildT) }`     | **Function builder** — types that can't be built from their constructor (`Retrofit.Builder()`, `Room.databaseBuilder()`, `OkHttpClient.Builder()`). Parameters injected like a constructor |
| `single { T(get(), get()) }`      | **Last-resort fallback** — only when a function builder doesn't fit |
| `singleOf(::T)` / `factoryOf(::T)`| Constructor DSL — supported, keep existing code; new code uses `single<T>()` / `factory<T>()` |

```kotlin
val appModule = module {
    // Classes you own — reified Compiler Plugin DSL
    single<HttpClient>()
    single<Repository>()                           // auto-resolves ctor from graph
    factory<RequestId>()
    viewModel<HomeViewModel>()

    // Third-party types — function builder (defined below the module)
    single { create(::buildRetrofit) }

    // WorkManager
    worker<SyncWorker>()                           // Compiler Plugin DSL — reified, ctor auto-resolved
    // Lambda form is fallback only:
    // worker { SyncWorker(androidContext(), get(), get()) }
}

fun buildRetrofit(client: OkHttpClient): Retrofit =
    Retrofit.Builder()
        .client(client)
        .baseUrl(BuildConfig.BASE_URL)
        .build()
```

## Interface binding

Infix `bind` by default (`references/rules.md` §1):

```kotlin
val appModule = module {
    single<RepositoryImpl>() bind Repository::class

    // Multiple interfaces
    single<RepositoryImpl>() bind Repository::class bind Persistable::class

    // Combined with other options
    single<RepositoryImpl>().withOptions {
        bind<Repository>()
        createdAtStart()
    }
}
```

`.bind<Repository>()` is equivalent — keep it where the project already uses it.

## Qualifiers

**Distinct types first** (`references/principles.md` rule 10). Two
implementations of one interface are injected by their own type — no qualifier:

```kotlin
class AuthHttpClient(val cfg: Config) : HttpClient
class PublicHttpClient(val cfg: Config) : HttpClient

class UserRepository(private val client: AuthHttpClient)   // asks for the role it needs

val networkModule = module {
    single<AuthHttpClient>()
    single<PublicHttpClient>()
}
```

A qualifier only when consumers must depend on the shared type, or when the
types can't differ (one third-party class built twice):

**`@Named` is the canonical Compiler Plugin DSL qualifier.** Declare it on the **class
declaration** or on a **constructor parameter**, then use the plain reified
`single<T>()` in the module. The Compiler Plugin reads `@Named` off the class/param
and registers the binding with that qualifier.

`@Qualifier` (custom annotation) works the same way and is the type-safe alternative.

**Do not write `single<T>(named("x")) { ... }` in Compiler Plugin DSL output** — that's
classic DSL (a lambda-backed overload). The Compiler Plugin DSL form has no qualifier
argument on `single<T>()`; the qualifier lives on the class.

### `@Named` — the default pattern

```kotlin
// Qualifier on the class declaration — this is what the Compiler Plugin reads
@Named("auth")
class AuthHttpClient(val cfg: Config) : HttpClient

@Named("public")
class PublicHttpClient(val cfg: Config) : HttpClient

// Qualifier on a constructor parameter — resolves the matching qualified dependency
class Service(@Named("auth") val client: HttpClient)

val networkModule = module {
    single<AuthHttpClient>()     // registered with qualifier named("auth")
    single<PublicHttpClient>()   // registered with qualifier named("public")
    single<Service>()            // @Named("auth") on ctor param wires AuthHttpClient
}
```

For types you can't annotate (third-party classes), put the qualifier on a
function builder — `create(::fn)` registers the definition with it:

```kotlin
@Named("authConfig")   fun authConfig(): Config = Config("...")
@Named("publicConfig") fun publicConfig(): Config = Config("...")

val networkModule = module {
    single { create(::authConfig) }     // registered with qualifier named("authConfig")
    single { create(::publicConfig) }   // registered with qualifier named("publicConfig")
}
```

A custom `@Qualifier` works the same way. A variant built from qualified
arguments is a function builder too — the qualifier goes on the function and on
its parameter:

```kotlin
@Auth fun authApiClient(@Named("authConfig") config: Config): ApiClient = ApiClient(config)

val networkModule = module {
    single { create(::authApiClient) }   // registered with qualifier<Auth>(), gets the authConfig Config
}
```

### `@Qualifier` — for type-safe qualifiers

```kotlin
@Qualifier annotation class Auth
@Qualifier annotation class Public

@Auth   class AuthHttpClient(val cfg: Config) : HttpClient
@Public class PublicHttpClient(val cfg: Config) : HttpClient

class Service(@Auth val client: HttpClient)

val networkModule = module {
    single<AuthHttpClient>()
    single<PublicHttpClient>()
    single<Service>()
}
```

### `@Property`

```kotlin
class ApiClient(@Property("api.url") val url: String)

val appModule = module {
    single<ApiClient>()
}
// load via startKoin { properties(mapOf("api.url" to "https://...")) }
```

### Call-site lookup

```kotlin
val auth: HttpClient      = get(named("auth"))        // @Named("auth")
val publicCli: HttpClient = get(qualifier<Public>())  // custom @Qualifier annotation class Public
```

## Parameter resolution

The compiler resolves every constructor parameter from the graph. Modifiers on
the parameter type control the resolution:

| Parameter type       | Resolves to                                    |
|----------------------|------------------------------------------------|
| `T`                  | Required — compile error if missing            |
| `T?`                 | Optional — `null` if no definition             |
| `List<T>`            | All definitions of `T` (or bound to `T`) — the same class twice needs a qualifier each (`references/principles.md` rule 10) |
| `Lazy<T>`            | Deferred — resolved on first access            |
| Default-valued param | Skipped — Kotlin default used, even when the graph has a definition (`skipDefaultValues`, `references/gradle.md`) |

For runtime parameters, the **preferred form is `@InjectedParam` on the
constructor** — the Compiler Plugin reads it whether the module uses annotations
or Compiler Plugin DSL:

```kotlin
// Class side — @InjectedParam marks the runtime-supplied param
class SessionToken(@InjectedParam val userId: String, val api: AuthApi)
class DetailViewModel(val repo: Repo, @InjectedParam val itemId: String) : ViewModel()

// Module side — Compiler Plugin DSL, no lambda needed
val appModule = module {
    factory<SessionToken>()
    viewModel<DetailViewModel>()
}

// Call site — identical to annotations style
val token: SessionToken = get { parametersOf(userId) }
val vm: DetailViewModel by viewModel { parametersOf(itemId) }
```

**Compiler Plugin 1.2.1** — when the definition sits in another Gradle module
than `startKoin`, `@InjectedParam` is lost and the build fails with
`[KOIN-D001]` on the parameter type (compiler plugin issue #115, fixed in the
next release). On 1.2.1, declare those definitions with the lambda form below.

Lambda-destructuring is a fallback only for classes you can't annotate
(third-party types with runtime params):

```kotlin
val appModule = module {
    factory { (url: String) -> ThirdPartyConnection(url, get()) }
}
```

## Scopes

```kotlin
val appModule = module {
    // Android scope archetypes
    activityScope { scoped<TabRouter>() }
    fragmentScope { scoped<FormState>() }
    viewModelScope { scoped<PageState>() }

    // Custom scope
    scope<SessionScope> {
        scoped<SessionToken>()
        scoped<AuthService>()
    }
}
```

## App entry point

DSL configuration (`references/rules.md` §5): `startKoin` loads **one app
module**, which `includes(...)` the child modules. Use the classic `startKoin`,
not the reified Compiler-Plugin variant (that one is for `@KoinApplication`).

```kotlin
import org.koin.core.context.startKoin

val appModule = module {
    includes(homeModule, settingsModule, dataModule)
}

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidContext(this@App)
            modules(appModule)
        }
    }
}
```

Mixing with an annotated module (only if the user asked for it):
`startKoin { modules(appModule); module<AnnotatedModule>() }` (`module` from
`org.koin.plugin.module.dsl`) — limits in `references/rules.md` §5.

## Retrieval

Entry points (Android, Compose, …): `references/entry-points.md`. Anywhere
else, constructor injection.

## Testing

`references/testing.md`.

## When a lambda is the right form

Form choice is in `references/rules.md` §1. A lambda (`single { … }`) fits when
the definition needs a custom expression:

- Runtime parameters on a class you can't annotate: `factory { (id: String) -> … }`
- Test overrides with hand-built fakes

Third-party builders and qualified variants use a function builder first
(`references/principles.md` rule 1, "Qualifiers" above).

## Not covered here

- Full Koin feature set — see https://insert-koin.io
- Annotations output — see `references/koin-annotations.md`
- Ktor / server / Jetpack Compose Multiplatform integration — see Koin docs
