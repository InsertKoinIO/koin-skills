# Hilt → Koin 4.x + Koin Compiler Plugin Migration Reference

> **Setup & versions** — Gradle: `references/gradle.md` · versions: `references/rules.md` §3 · exact syntax: `references/koin-annotations.md` / `references/koin-compiler-plugin-dsl.md`.

## Table of Contents
1. [Progressive Migration with koin-dagger-bridge](#progressive-migration)
2. [Annotation Mapping](#annotation-mapping)
3. [Gradle Changes](#gradle-changes)
3. [Module Conversion](#module-conversion)
4. [Component/Entry Point Conversion](#component-conversion)
5. [ViewModel Migration](#viewmodel-migration)
6. [Scope Mapping](#scope-mapping)
7. [Assisted Inject](#assisted-inject)
8. [Multibindings](#multibindings)
9. [WorkManager](#workmanager)
10. [Compose Integration](#compose-integration)
11. [Navigation Compose Scoping](#navigation-compose-scoping)

---

## Progressive Migration

Do **not** rewrite existing Hilt/Dagger modules in place. Instead:

1. Set Koin up **alongside** the existing container — the `koin-setup` skill (Gradle, style, start)
2. Add the **`koin-dagger-bridge`** bridge so Koin and Hilt/Dagger can coexist
3. Move definitions from Hilt modules into the Koin module one feature at a time
4. Inject from either container at the call sites until migration is complete
5. Remove Hilt entry points, modules, and dependencies only after every binding has moved

### Option A — library bridge

```kotlin
implementation("io.insert-koin:koin-dagger-bridge:<version>")
```

The bridge lets Hilt-generated entry points resolve dependencies that have already moved
into Koin, and lets Koin definitions request bindings that still live in Hilt — keeping
the app buildable and runnable at every step.

### Option B — manual bridge, co-located in the consumer's `@Module` (recommended)

Put the bridge function inside the feature's own `@Module`, not a shared
aggregator. A1 per-module verification only sees the module's own bindings;
sibling aggregators are invisible.

```kotlin
@EntryPoint
@InstallIn(SingletonComponent::class)
interface UserDataEntryPoint {
    fun userDataRepository(): UserDataRepository
}

@Module
@Configuration
@ComponentScan("com.acme.feature.settings")
class SettingsFeatureModule {
    @Singleton
    fun userDataRepository(context: Context): UserDataRepository =
        EntryPointAccessors.fromApplication(context, UserDataEntryPoint::class.java)
            .userDataRepository()
}

@KoinViewModel
class SettingsViewModel(private val userData: UserDataRepository) : ViewModel()
```

When the binding migrates into Koin, delete the bridge function and the
`@EntryPoint` interface from this module — blast radius stays local.

Several consumers need the same bridge → "Bridging with the existing DI" in the `di-migration` SKILL.md.

### Option C — `dagger<T>()` from `koin-dagger-bridge` (for Compiler Plugin DSL modules)

If your migration output style is Compiler Plugin DSL (`module { }` blocks) rather than
annotations, use the bridge's `Scope.dagger<T>()` (`org.koin.android.dagger.dagger`) —
don't redefine it. **`T` is a Hilt `@EntryPoint` interface, not the binding:**
`dagger<T>()` returns the entry point; call its accessor to get the binding.

Inside the feature's own Koin `module { }` (same co-location principle):

```kotlin
import org.koin.android.dagger.dagger

@EntryPoint
@InstallIn(SingletonComponent::class)
interface UserDataEntryPoint {
    fun userDataRepository(): UserDataRepository
}

val settingsModule = module {
    single { dagger<UserDataEntryPoint>().userDataRepository() }
    viewModel<SettingsViewModel>()
}
```

Requires `androidContext(...)` configured in `startKoin { }`. Every `dagger<T>()` call is a migration TODO —
remove when the target moves into Koin. Keep `dagger<T>()` calls inside the
consumer module to stay friendly with A1 verification.

### Compile-time graph check during bridging

**With co-located bridges (Option B or C as described), strict A1 verification
stays green — you don't need to relax anything.** Every consumer module has
its bridge function locally declared, so A1's per-module check finds it.

Only relax the graph check if you explicitly choose an aggregator pattern
(shared `HiltBridgeModule` feeding multiple consumers) — which is a
configuration you're taking on deliberately, not a migration requirement.

---

## Annotation Mapping

| Hilt Annotation              | Koin Compiler Plugin Equivalent                       |
|------------------------------|-------------------------------------------------------|
| `@HiltAndroidApp`           | `@KoinApplication` + `startKoin<App>()`               |
| `@AndroidEntryPoint`        | Remove — use `by inject()` or `by viewModel()`       |
| `@Inject constructor(...)`  | `@Factory` on the class (new instance per injection)  |
| `@Module`                   | `@Module` class with `@ComponentScan` or `includes`  |
| `@InstallIn(SingletonComponent::class)` | `@Singleton` on each binding              |
| `@InstallIn(ActivityComponent::class)` | `@Scope(Activity::class)` on bindings     |
| `@InstallIn(ViewModelComponent::class)` | `@KoinViewModel` on ViewModel class      |
| `@Provides`                 | `@Singleton` / `@Factory` on a function in `@Module`  |
| `@Binds`                    | `@Singleton` on impl class (auto-binds to interface)  |
| `@Singleton`                | `@Singleton`                                           |
| `@ViewModelScoped`          | `@KoinViewModel` (inherently scoped)                  |
| `@ActivityScoped`           | `@Scope(Activity::class)` + `@Scoped`                |
| `@Qualifier` / `@Named`    | **Reuse as-is** — custom `@Qualifier` annotations work directly |
| `@ViewModelScoped`          | `@KoinViewModel` (inherently scoped)                   |
| `@AssistedInject`           | `@InjectedParam` on runtime parameters                 |
| `@HiltWorker`               | `@KoinWorker`                                          |


## Gradle Changes

### Step 1: Remove Hilt dependencies

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
}
```

### Step 2: Add Koin + Compiler Plugin

Add Koin per `references/gradle.md` — Compiler Plugin, `koin-bom`, only the artifacts the project needs (KMP: shared artifacts in `commonMain`, no per-target configuration). Versions: `references/rules.md` §3.


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
// Auto-bind: implements single interface → binding auto-detected by compiler.
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

While migration is in progress, the `Application` class owns both graphs:

```kotlin
import org.koin.plugin.module.dsl.startKoin

@HiltAndroidApp
@KoinApplication
class App : Application() {
    override fun onCreate() {
        super.onCreate()                              // Hilt graph ready after this
        startKoin<App> { androidContext(this@App) }   // Koin after — order matters
    }
}
```

**Ordering is critical:** `super.onCreate()` must run first so the Hilt graph is
live by the time Koin starts. Any `@Singleton fun` bridge function (Option B
above) calling `EntryPointAccessors.fromApplication(...)` needs a fully-initialized
Hilt graph underneath.

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
| `ServiceComponent`           | `@Scope(Service::class)` or `@Factory`                 | `scope<Service> { scoped { ... } }` |
| Custom `@DefineComponent`    | `@Scope(CustomType::class)`                            | `scope<CustomType> { scoped { ... } }` |

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

Hilt multibindings (Set/Map) don't have a direct annotation equivalent.
Use a `@Module` with a factory function:

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
```

```kotlin
// AFTER: Koin
@Singleton
class LoggingInterceptor : Interceptor { /* ... */ }

@Singleton
class AuthInterceptor(private val tokenProvider: AuthTokenProvider) : Interceptor { /* ... */ }

@Module
class InterceptorModule {
    @Singleton
    fun provideInterceptors(
        logging: LoggingInterceptor,
        auth: AuthInterceptor
    ): Set<Interceptor> = setOf(logging, auth)
}
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
