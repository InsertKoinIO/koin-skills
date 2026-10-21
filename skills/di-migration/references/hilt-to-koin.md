# Hilt → Koin 4.x + Koin Compiler Plugin Migration Reference

> **Setup & versions** — Gradle: `references/gradle.md` · versions: `references/rules.md` §3 · exact syntax: `references/koin-annotations.md` / `references/koin-compiler-plugin-dsl.md`.

## Table of Contents
1. [Progressive Migration](#progressive-migration)
2. [Annotation Mapping](#annotation-mapping)
3. [Gradle Changes](#gradle-changes)
4. [Module Conversion](#module-conversion)
5. [Component/Entry Point Conversion](#component-conversion)
6. [ViewModel Migration](#viewmodel-migration)
7. [Scope Mapping](#scope-mapping)
8. [Assisted Inject](#assisted-inject)
9. [Multibindings](#multibindings)
10. [WorkManager](#workmanager)
11. [Compose Integration](#compose-integration)
12. [Navigation Compose Scoping](#navigation-compose-scoping)

---

## Progressive Migration

Do **not** rewrite existing Hilt/Dagger modules in place. Instead:

1. Set Koin up **alongside** the existing container — Step 3 (Gradle) and Step 5 (wiring) of the `di-migration` workflow
2. Add the **`koin-dagger-bridge`** bridge so Koin definitions can read bindings still in Hilt
3. Move definitions from Hilt modules into the Koin module one feature at a time
4. Inject from either container at the call sites until migration is complete
5. Remove Hilt entry points, modules, and dependencies only after every binding has moved (Step 8)

Bridging (`dagger<T>()` on a Hilt `@EntryPoint`, `EntryPointAccessors` fallback,
co-location, startup order): `references/bridging.md`. `koin-dagger-bridge` is
one direction — Koin reads Hilt, Hilt doesn't resolve Koin definitions. A Hilt
binding that needs one already moved: "The other direction" in
`references/bridging.md` — leaf-first avoids it.

---

## Annotation Mapping

| Hilt Annotation              | Koin Compiler Plugin Equivalent                       |
|------------------------------|-------------------------------------------------------|
| `@HiltAndroidApp`           | `@KoinApplication` + `startKoin<App>()`               |
| `@AndroidEntryPoint`        | Remove — use `by inject()` or `by viewModel()`       |
| `@Inject constructor(...)`  | `@Factory` on the class (new instance per injection)  |
| `@Module`                   | `@Module` class with `@ComponentScan` or `includes`  |
| `@InstallIn(SingletonComponent::class)` | `@Singleton` on each binding              |
| `@InstallIn(ActivityComponent::class)` | `@ActivityScope` on bindings (`org.koin.android.annotation`) |
| `@InstallIn(ViewModelComponent::class)` | `@KoinViewModel` on ViewModel class      |
| `@Provides`                 | `@Singleton` / `@Factory` on a function in `@Module`  |
| `@Binds`                    | `@Singleton` on impl class (auto-binds to interface)  |
| `@Singleton`                | `@Singleton`                                           |
| `@ViewModelScoped`          | `@ViewModelScope`                                      |
| `@ActivityScoped`           | `@ActivityScope` (`org.koin.android.annotation`)       |
| `@Qualifier` / `@Named`    | **Reuse as-is** — custom `@Qualifier` annotations work directly |
| `@AssistedInject`           | `@InjectedParam` on runtime parameters                 |
| `@HiltWorker`               | `@KoinWorker`                                          |


## Gradle Changes

### Add Koin + Compiler Plugin (Step 3)

Add Koin per `references/gradle.md` — Compiler Plugin, `koin-bom`, only the artifacts the project needs (KMP: shared artifacts in `commonMain`, no per-target configuration). Versions: `references/rules.md` §3. Hilt stays in place.

### Remove Hilt — Step 8, after the last binding moved

```kotlin
// REMOVE from build.gradle.kts (app)
plugins {
    // id("dagger.hilt.android.plugin")  ← REMOVE
    // id("com.google.devtools.ksp")     ← REMOVE if only used for Hilt
}

dependencies {
    // REMOVE all of these:
    // implementation("com.google.dagger:hilt-android:2.x")
    // ksp("com.google.dagger:hilt-compiler:2.x")
    // implementation("androidx.hilt:hilt-navigation-compose:1.x")
    // implementation("androidx.hilt:hilt-work:1.x")
    // ksp("androidx.hilt:hilt-compiler:1.x")
    // implementation("io.insert-koin:koin-dagger-bridge")
}
```

## Module Conversion

### Hilt @Provides module → Koin @Module

```kotlin
// BEFORE: Hilt
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient =
        OkHttpClient.Builder().build()

    @Provides
    @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit =
        Retrofit.Builder()
            .client(client)
            .baseUrl(BASE_URL)
            .build()

    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService =
        retrofit.create(ApiService::class.java)
}
```

```kotlin
// AFTER: Koin Compiler Plugin
@Module
class NetworkModule {
    @Singleton
    fun provideOkHttpClient(): OkHttpClient =
        OkHttpClient.Builder().build()

    @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit =
        Retrofit.Builder()
            .client(client)
            .baseUrl(BASE_URL)
            .build()

    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService =
        retrofit.create(ApiService::class.java)
}
```

### Hilt @Binds module → Koin annotation with binds

```kotlin
// BEFORE: Hilt
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    @Singleton
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository
}
```

```kotlin
// AFTER: Koin — annotate the implementation directly
@Singleton
class UserRepositoryImpl(
    private val api: ApiService,
    private val dao: UserDao
) : UserRepository
// Auto-bind: the compiler binds the interfaces it implements.
// No explicit binds needed. No separate module class needed — @ComponentScan discovers this.
```

### Hilt @Inject constructor → Koin @Factory

`@Inject` in Hilt means "this class can be created by the DI framework" — it creates a new instance
each time by default. This maps to `@Factory` in Koin. Use `@Singleton` only when Hilt also has `@Singleton`.

```kotlin
// BEFORE: Hilt — @Inject without @Singleton = new instance each time
class UserRepository @Inject constructor(
    private val api: ApiService,
    private val dao: UserDao
)
```

```kotlin
// AFTER: Koin — @Inject maps to @Factory
@Factory
class UserRepository(
    private val api: ApiService,
    private val dao: UserDao
)
// Dependencies auto-resolved from the Koin graph at compile time.
// If the original Hilt class had @Singleton, use @Singleton instead of @Factory.
```

## Parameter Resolution

Constructor and function parameters (`T`, `T?`, `Lazy<T>`, `List<T>`, `@InjectedParam`, qualifiers, properties) are resolved by the Compiler Plugin — see "Parameter resolution" in `references/koin-compiler-plugin-dsl.md` and "Parameters & qualifiers" in `references/koin-annotations.md`.

## Component Conversion

Hilt components are implicit (generated). Koin uses `@Module` composition + `@KoinApplication`:

```kotlin
// BEFORE: Hilt — component hierarchy is auto-generated
// @HiltAndroidApp generates SingletonComponent → ActivityComponent → FragmentComponent
@HiltAndroidApp
class App : Application()
```

```kotlin
// AFTER: Koin — auto-discovery via the @Module + @Configuration + @ComponentScan triad
// Each Gradle module declares its own module class with the triad; the app just needs
// @KoinApplication. No modules(...) call required.

@Module
@Configuration
@ComponentScan("com.acme.app")
class AppModule

// Application — @KoinApplication + reified startKoin<App>
import org.koin.plugin.module.dsl.startKoin   // NOT org.koin.core.context.startKoin

@KoinApplication
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin<App> {
            androidContext(this@App)
        }
    }
}
```

### Dual-container Application (Hilt + Koin coexisting during migration)

`@HiltAndroidApp` and `@KoinApplication` on the same `Application`, Hilt started
first — "Two containers at startup" in `references/bridging.md`.

### Convention plugin gotcha

Gradle convention plugins: see "Convention plugins" in `references/gradle.md`.

### Entry Points

```kotlin
// BEFORE: Hilt
@AndroidEntryPoint
class MainActivity : AppCompatActivity() {
    @Inject lateinit var analytics: Analytics
    private val viewModel: MainViewModel by viewModels()
}
```

```kotlin
// AFTER: Koin
class MainActivity : AppCompatActivity() {
    private val analytics: Analytics by inject()
    private val viewModel: MainViewModel by viewModel()
}
```

## ViewModel Migration

```kotlin
// BEFORE: Hilt
@HiltViewModel
class DetailViewModel @Inject constructor(
    private val repo: ItemRepository,
    private val savedStateHandle: SavedStateHandle
) : ViewModel()

// Usage in Activity:
private val viewModel: DetailViewModel by viewModels()
// Usage in Compose:
val viewModel: DetailViewModel = hiltViewModel()
```

```kotlin
// AFTER: Koin Compiler Plugin
@KoinViewModel
class DetailViewModel(
    private val repo: ItemRepository,
    private val savedStateHandle: SavedStateHandle  // Auto-resolved by Koin
) : ViewModel()

// Usage in Activity/Fragment:
private val viewModel: DetailViewModel by viewModel()

// Usage in Compose:
val viewModel = koinViewModel<DetailViewModel>()
```

### ViewModel with runtime parameters

```kotlin
// BEFORE: Hilt — needs @AssistedInject + @AssistedFactory
@HiltViewModel(assistedFactory = PlayerViewModel.Factory::class)
class PlayerViewModel @AssistedInject constructor(
    private val repo: PlayerRepository,
    @Assisted private val playerId: String
) : ViewModel() {
    @AssistedFactory
    interface Factory {
        fun create(playerId: String): PlayerViewModel
    }
}
```

```kotlin
// AFTER: Koin — much simpler with @InjectedParam
@KoinViewModel
class PlayerViewModel(
    private val repo: PlayerRepository,
    @InjectedParam private val playerId: String
) : ViewModel()

// Usage:
val viewModel: PlayerViewModel by viewModel { parametersOf("player_123") }
// Or in Compose:
val viewModel = koinViewModel<PlayerViewModel> { parametersOf("player_123") }
```

## Scope Mapping

Koin provides **scope archetype annotations** that map directly to Android lifecycle scopes:

| Hilt Scope                   | Koin Scope Archetype Annotation                        | Generated DSL                    |
|------------------------------|--------------------------------------------------------|----------------------------------|
| `SingletonComponent`         | `@Singleton` (application-wide)                           | `single { ... }`                 |
| `ActivityRetainedComponent`  | `@ActivityRetainedScope`                               | `activityRetainedScope { scoped { ... } }` |
| `ActivityComponent`          | `@ActivityScope`                                       | `activityScope { scoped { ... } }` |
| `FragmentComponent`          | `@FragmentScope`                                       | `fragmentScope { scoped { ... } }` |
| `ViewModelComponent`         | `@ViewModelScope`                                      | `viewModelScope { scoped { ... } }` |
| `ServiceComponent`           | `@ServiceScoped` → `@Scope(MyService::class)` + `@Scoped`; unscoped (no instance shared across the service's lifetime) → `@Factory`, no scope | `scope<MyService> { scoped { ... } }` |
| Custom `@DefineComponent`    | `@Scope(CustomType::class)` + `@Scoped`                | `scope<CustomType> { scoped { ... } }` |

Koin side (archetype annotations, DSL, component usage, custom scopes): `references/scopes.md`.

## Assisted Inject

```kotlin
// BEFORE: Hilt Assisted Inject
class PlayerViewModel @AssistedInject constructor(
    private val repo: PlayerRepository,
    @Assisted private val playerId: String
) : ViewModel() {

    @AssistedFactory
    interface Factory {
        fun create(playerId: String): PlayerViewModel
    }
}
```

```kotlin
// AFTER: Koin — @InjectedParam replaces @Assisted entirely
@KoinViewModel
class PlayerViewModel(
    private val repo: PlayerRepository,
    @InjectedParam private val playerId: String
) : ViewModel()

// Usage — parametersOf at the call site
val viewModel: PlayerViewModel by viewModel { parametersOf("player_123") }
```

## Multibindings

Same as Dagger — each element its own `@Named` definition bound to `T`,
consumers inject `List<T>`: "Multibindings" in `references/dagger-to-koin.md`.

```kotlin
// BEFORE: Hilt
@Module
@InstallIn(SingletonComponent::class)
abstract class InterceptorModule {
    @Binds @IntoSet
    abstract fun bindLogging(impl: LoggingInterceptor): Interceptor

    @Binds @IntoSet
    abstract fun bindAuth(impl: AuthInterceptor): Interceptor
}
class OkHttpFactory @Inject constructor(private val interceptors: Set<@JvmSuppressWildcards Interceptor>)
```

```kotlin
// AFTER: Koin
@Singleton @Named("logging")
class LoggingInterceptor : Interceptor { /* ... */ }

@Singleton @Named("auth")
class AuthInterceptor(private val tokenProvider: AuthTokenProvider) : Interceptor { /* ... */ }

@Factory
class OkHttpFactory(private val interceptors: List<Interceptor>)
```

## WorkManager

```kotlin
// BEFORE: Hilt
@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val api: ApiService
) : CoroutineWorker(context, params)
```

AFTER: `@KoinWorker` + `workManagerFactory()` — "WorkManager" in `references/entry-points.md`.

## Compose Integration

```kotlin
// BEFORE: Hilt + Compose
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val viewModel: MainViewModel = hiltViewModel()
        }
    }
}
```

```kotlin
// AFTER: Koin + Compose
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val viewModel = koinViewModel<MainViewModel>()   // Koin started in Application — no wrapper needed
        }
    }
}
```

## Navigation Compose Scoping

```kotlin
// BEFORE: Hilt — scoped to nav backstack entry
val viewModel: DetailViewModel = hiltViewModel()

// AFTER: Koin — scoped to nav backstack entry (the default owner)
val viewModel = koinViewModel<DetailViewModel>()
```

For nested navigation graphs with shared ViewModels (`koin-compose-viewmodel-navigation`):
```kotlin
composable<DetailRoute> { backStackEntry ->
    val shared = backStackEntry.sharedKoinViewModel<SharedViewModel>(navController)
}
```

Navigation 3 and the full navigation guidance: `references/entry-points.md`.
