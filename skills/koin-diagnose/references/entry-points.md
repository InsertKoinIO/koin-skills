# Koin Entry Points

Where the framework creates the object, there's no constructor to inject into.
Each entry point has a dedicated Koin API — **none of them needs
`KoinComponent`** (`references/principles.md` rule 2). These APIs are the same
in both definition styles.

Everywhere else: constructor injection.

## App start

How to configure Koin (Annotations discovery / DSL app module, KMP `initApp()`,
logger): `references/rules.md` §5. Where to start it, per project type:

| Project | Start |
|---|---|
| Android app (Views or Compose) | `Application.onCreate()` — after the existing container if one is still running |
| KMP | Shared `initApp()` in `commonMain`, called by each native entry point (Android `Application`, iOS app init, desktop `main`) |
| Compose Multiplatform app started from Compose | `KoinApplication(configuration = …)` in the root composable — below |
| Ktor | `install(Koin) { … }` — "Ktor server" below |
| Code before `Application.onCreate()` (ContentProvider) | `koin-androidx-startup` — "Other Android components" below |
| SDK / library | Isolated context (`koinApplication { }`), never `startKoin` — "Isolated context" below |

### Values known at startup

A value the platform hands over when the app starts — what a Dagger
`@BindsInstance`, a `@Component.Factory` argument or a Metro
`@DependencyGraph.Factory` `@Provides` parameter carries. It's not a
definition: give it to Koin in `startKoin`.

| Value | In `startKoin { }` | Consumer |
|---|---|---|
| Android `Context` / `Application` | `androidContext(this@MainApplication)` | Plain `Context` / `Application` parameter |
| Any other object (platform flags, a resource id, a config) | `koin.declare(value)` — qualified: `koin.declare(value, qualifier<Q>())` | `@Provided` parameter (+ the qualifier annotation) |
| A configuration value (properties) | `properties(mapOf("api.url" to url))` — file / environment loaders: Properties in `references/index.md` | `@Property("api.url")` parameter — file / environment values are `String`s |

```kotlin
// KMP — commonMain: each platform passes its values to initApp()
@KoinApplication object KoinApp

fun initApp(appConfig: AppConfig, platformConfig: KoinAppDeclaration? = null) =
    startKoin<KoinApp> {
        koin.declare(appConfig)                                 // consumer: @Provided appConfig: AppConfig
        platformConfig?.invoke(this)
    }

// androidMain — Application.onCreate()
initApp(appConfig = AppConfig(debug = BuildConfig.DEBUG)) {
    androidContext(this@MainApplication)
    koin.declare(BuildConfig.API_URL, qualifier<ApiUrl>())   // consumer: @Provided @ApiUrl url: String
}
```

### Compose app start

`KoinApplication()` (composable) starts Koin from Compose. Use it only when
nothing else starts Koin:

| App | Start |
|---|---|
| Android app (Compose UI or not) | `Application` — `rules.md` §5. No `KoinApplication()` |
| KMP with a common start function (`initApp()`) | That function, called by each native entry point. No `KoinApplication()` |
| Compose Multiplatform app started from Compose, or Koin started directly from the Compose part | `KoinApplication()` in the root composable |

```kotlin
// DSL configuration
@Composable
fun App() {
    KoinApplication(configuration = koinConfiguration { modules(appModule) }) {
        MainScreen()
    }
}

// Annotations configuration
@KoinApplication object KoinApp

@Composable
fun App() {
    KoinApplication(configuration = koinConfiguration<KoinApp>()) {   // org.koin.plugin.module.dsl.koinConfiguration
        MainScreen()
    }
}
```

Other Compose start / context APIs (`KoinContext`, older `KoinApplication`
overloads) are deprecated — don't emit them.

## Android components — `Activity`, `Fragment`, `Service`

Extensions from **`koin-android`**:

```kotlin
class MyActivity : AppCompatActivity() {
    private val repo: Repository by inject()          // lazy
    private val vm: HomeViewModel by viewModel()      // Activity-scoped ViewModel
}

class MyFragment : Fragment() {
    private val vm: HomeViewModel by viewModel()          // Fragment-scoped ViewModel
    private val shared: SharedVM by activityViewModel()   // shared with the host Activity
}

class SyncService : Service() {
    private val repo: Repository by inject()
}
```

- **Fragment constructor injection** — only if the user wants Fragments injected
  by constructor (niche): `setupKoinFragmentFactory()` at start, then declare the
  Fragment as a definition.
- **Android scopes** (`@ActivityScope`, `@FragmentScope`, `activityScope()`) —
  advanced, see `references/scopes.md`.

## ViewModel

Declare once, retrieve at the entry point. Same rule as every class: dependencies
through the constructor.

```kotlin
// Declaration
@KoinViewModel class DetailViewModel(val repo: Repo, val handle: SavedStateHandle) : ViewModel()  // Annotations
viewModel<DetailViewModel>()                                                                       // Compiler Plugin DSL

// Retrieval
val vm: DetailViewModel by viewModel()     // Activity / Fragment (koin-android)
val vm = koinViewModel<DetailViewModel>()  // Compose (koin-compose-viewmodel)
```

- **`SavedStateHandle`** — injected automatically as a constructor parameter.
  No declaration needed.
- **Runtime parameters** — `@InjectedParam` on the constructor + `parametersOf(...)`
  at the call site. Unlike `SavedStateHandle`, injected params are **not saved**:
  they're lost on process death. For state that must survive (navigation
  arguments, user input), read it from `SavedStateHandle`.
- **Compose & KMP** — `koin-compose-viewmodel`: `@KoinViewModel` /
  `viewModel<T>()` in `commonMain`, `koinViewModel()` in Compose Multiplatform.
  The Koin context is picked up automatically — no wrapper needed. There is
  **no `activityViewModel()` equivalent** in KMP / Compose Multiplatform —
  `activityViewModel()` is Android-only (`koin-android`). For dependencies
  tied to a ViewModel's lifetime, the advanced case is the **ViewModel scope**
  (`@ViewModelScope` or `viewModelScope { }` in DSL) — see `references/scopes.md`.

## Compose

```kotlin
@Composable
fun HomeScreen(
    vm: HomeViewModel = koinViewModel(),          // default parameter: previews and tests pass a fake
) {
    val listState = koinInject<FeedListState>()   // state holder tied to this composable
}

@Composable
fun DetailScreen(id: String, vm: DetailViewModel = koinViewModel { parametersOf(id) }) { … }
```

- **`koinViewModel()`** — for ViewModels. A ViewModel outlives the composable
  (configuration changes, back stack).
- **`koinInject()`** — for state holders and any component tied to the
  composable's lifecycle.
- **ViewModel as a default parameter** — resolve at the screen entry with
  `vm: T = koinViewModel()`, so previews and tests can pass a fake. Pass state
  down to child composables, not the ViewModel.
- **Runtime parameters** — `koinViewModel { parametersOf(…) }` and
  `koinInject { parametersOf(…) }`, same as on Android.
- **Several ViewModels of one type on one screen** (a list where each item has
  its own) — give each a key: `koinViewModel<ItemViewModel>(key = id) {
  parametersOf(id) }`. Without a key, all items share the first ViewModel and
  its parameters. Migrating: keep every `key =` the source call site had.
- **Qualified dependency** — `koinInject<String>(qualifier<BaseUrl>())` for a
  custom `@Qualifier` annotation `BaseUrl`.
- **Scoped composables** — advanced, see `references/scopes.md`.

## Navigation

**Recommended for modern development: Compose + Navigation 3** — the official
Koin integration, built with the Google / Android team. Also the choice for KMP
apps that share UI (Compose Multiplatform + Compose Nav3).

### Navigation 3 — `koin-compose-navigation3`

Declare each destination in a Koin module, then let Koin provide the entries:

```kotlin
// Module — one navigation entry per route
val homeModule = module {
    viewModel<HomeViewModel>()
    navigation<HomeRoute> { route ->
        HomeScreen(vm = koinViewModel())
    }
}

// Root composable — Koin aggregates every declared entry
@Composable
fun AppNavigation() {
    val backStack = rememberNavBackStack(HomeRoute)
    NavDisplay(
        backStack = backStack,
        onBack = { backStack.removeLastOrNull() },
        entryDecorators = listOf(
            rememberSaveableStateHolderNavEntryDecorator(),
            rememberViewModelStoreNavEntryDecorator(),   // one ViewModel store per entry — koinViewModel() per screen
        ),
        entryProvider = koinEntryProvider(),
    )
}
```

- `navigation<Route> { }` also works inside a scope (`activityScope { }`) to reach
  scoped dependencies.
- From an Android `Activity`: `val entryProvider by entryProvider()`.
- The API is marked `@KoinExperimentalAPI` — opt in where it's used.
- **DSL only for now** — Annotations / Compiler Plugin support will come in a
  later release. In an Annotations project, keep the navigation entries in a
  dedicated DSL module and tell the user it's the one DSL module (a mixing
  case, `rules.md` §5).

### Navigation 2 (Navigation Compose) — `koin-compose-viewmodel-navigation`

ViewModel per destination: `koinViewModel()`. ViewModel shared by the screens
of a nav graph:

```kotlin
composable<FirstScreenRoute> { backStackEntry ->
    val shared = backStackEntry.sharedKoinViewModel<SharedViewModel>(navController)
}
```

`koinNavViewModel()` is deprecated — use `koinViewModel()`.

### Fragment-based Navigation

Still supported, but not recommended for modern development. Don't propose it
for new code.

## WorkManager — `koin-androidx-workmanager`

Workers get constructor injection like any class:

```kotlin
// Annotations (Koin Annotations + Compiler Plugin)
@KoinWorker
class SyncWorker(ctx: Context, params: WorkerParameters, val repo: Repo) : CoroutineWorker(ctx, params)

// Compiler Plugin DSL
worker<SyncWorker>()

// Start — required when using Workers: Koin creates them
startKoin {
    androidContext(this@App)
    workManagerFactory()
}
```

`workManagerFactory()` initializes WorkManager with Koin's factory, so the
default WorkManager initializer must be removed from the manifest
(`androidx.work.WorkManagerInitializer` under `InitializationProvider`),
otherwise WorkManager initializes twice.

KMP background work: no Koin API yet.

## Ktor server — `koin-ktor`

Start Koin with the Ktor plugin. Both forms — DSL `modules(...)` and
Annotations `withConfiguration<T>()` — are compile-time checked by the Compiler
Plugin.

```kotlin
fun Application.module() {
    install(Koin) {
        slf4jLogger()                 // koin-logger-slf4j, only if needed
        modules(appModule)            // DSL configuration
        // withConfiguration<App>()   // Annotations configuration — @KoinApplication type
    }

    routing {
        val service by inject<UserService>()   // Route / Routing / Application / ApplicationCall extensions
        get("/users") { call.respond(service.all()) }
    }
}
```

- `withConfiguration<T>()` (`org.koin.plugin.module.dsl`) loads the modules
  discovered for a `@KoinApplication` type into the plugin's Koin application.
- `koinModule { }` / `koinModules(...)` add modules from another Ktor module.
  `Application.koin { }` is deprecated.
- Advanced: per-request dependencies (`requestScope { }` + `call.scope`).
  Really advanced: `KoinIsolated` plugin, bridge with Ktor's own DI.

## Other Android components

No dedicated Koin API for these:

- **`BroadcastReceiver`** — implement `KoinComponent` (service locator,
  `references/principles.md` rule 2):

  ```kotlin
  class AlarmReceiver : BroadcastReceiver(), KoinComponent {
      private val scheduler: Scheduler by inject()
      override fun onReceive(context: Context, intent: Intent) { scheduler.fire() }
  }
  ```

- **`ContentProvider` / code running before `Application.onCreate()`** — Koin
  isn't started yet. Start Koin with AndroidX App Startup —
  **`koin-androidx-startup`**:

  ```kotlin
  class App : Application(), KoinStartup {          // org.koin.androix.startup.KoinStartup
      override fun onKoinStartup() = koinConfiguration {
          androidContext(this@App)
          modules(appModule)                         // Annotations: koinConfiguration<App>()
      }
  }
  ```

  `KoinInitializer` starts Koin through App Startup instead of
  `Application.onCreate()` — no `startKoin` call. Other initializers that need
  Koin declare `KoinInitializer::class` in their `dependencies()`. The API is
  marked `@KoinExperimentalAPI`.

- **Custom `View`** — depends on the project. **Ask the user** which they want:
  pass dependencies from the hosting Activity / Fragment / composable
  (constructor or setter, no Koin in the View), or `KoinComponent` in the View
  (service locator, with the acknowledgement of rule 2).

## iOS / Swift (KMP)

**Start** — Swift calls the shared start function from common code
(`rules.md` §5) in the app's init:

```swift
@main
struct iOSApp: App {
    init() { InitAppKt.doInitApp() }   // Kotlin `initApp()` exported to Swift
    var body: some Scene { WindowGroup { ContentView() } }
}
```

**Getting shared objects** — Swift can't use Kotlin's reified `inject()`. Two
ways, simplest first:

- **Export functions** from `iosMain` that return what Swift needs.
- **A bridge class** in `iosMain` that uses Koin as a service locator — an
  accepted case: it's the platform boundary, not a normal layer.

```kotlin
// iosMain
class SharedBridge : KoinComponent {
    fun homeViewModel(): HomeViewModel = get()
}
```

Better Swift integration is in progress — not available yet.

**SwiftUI** — SwiftUI can consume shared ViewModels through Compose
Multiplatform. Native SwiftUI screens need a dedicated integration (out of
Koin's scope).

## Isolated context — SDKs, white-label, isolated containers

An isolated context is a **`koinApplication { }` instance instead of
`startKoin { }`**. `startKoin` registers Koin globally — fine for an app, wrong
for an SDK or a private container: the host app may use Koin too. The instance
is held in the SDK (or any private space):

```kotlin
object MySdkKoin {
    val koinApp = koinApplication { modules(sdkModule) }   // Annotations: koinApplication<SdkApp>()
    val koin: Koin get() = koinApp.koin
}
```

The default entry-point extensions (`by inject()`, `by viewModel()` on Android
components…) look up the **global** Koin. In an isolated context they need to
know where the instance is:

- **Android UI / classes** — a custom component that redefines `getKoin()`:

  ```kotlin
  internal interface SdkKoinComponent : KoinComponent {
      override fun getKoin(): Koin = MySdkKoin.koin
  }

  class SdkActivity : AppCompatActivity(), SdkKoinComponent {
      private val repo: SdkRepository by inject()   // resolved from the SDK's container
  }
  ```

- **Compose** — simpler and more autonomous: `KoinIsolatedContext` cascades the
  context to every child composable automatically.

  ```kotlin
  @Composable
  fun SdkScreen() {
      KoinIsolatedContext(context = MySdkKoin.koinApp) {
          SdkContent()   // koinInject() / koinViewModel() resolve from the SDK
      }
  }
  ```

- **Tests** — override `getKoin()` in the test to point at the isolated instance.
- Ktor: `KoinIsolated` plugin (really advanced).

Inside the SDK graph, constructor injection as usual. `SdkKoinComponent` is not
a service locator in normal layers: it only tells entry points which Koin
instance to use (`references/principles.md` rule 2).
