# Bridging with an existing DI container

Koin next to Hilt, Dagger, Toothpick, Kodein or Metro: during a migration
(`di-migration`), or for an app that keeps both (`koin-setup`, `koin`).

## Principle

- **Koin reads what the old container still owns.** A bridge is a Koin
  definition whose body asks the old container for the instance.
- **Co-locate the bridge in the consumer module** — the `@Module` or
  `module { }` of the feature that needs it: it moves and disappears with that
  feature. The Compiler Plugin checks the full graph at the Koin entry point
  (`startKoin`), so the bridge must be in a module that graph loads.
- **Promote on demand** — several consumers need the same bridge and the
  duplication hurts → one `SharedBridgeModule` (`@Module`, no `@Configuration`),
  pulled into each consumer with `@Module(includes = [SharedBridgeModule::class])`
  (DSL: `includes(sharedBridgeModule)`).
- **Migrating** → every bridge is a TODO: delete it when its binding moves into
  Koin. **Keeping both** → bridges are permanent wiring.
- Kotzilla sees only the Koin side of a bridge ("Expected behavior" in
  `references/kotzilla.md`).

## Hilt — `koin-dagger-bridge`

The recommended Hilt path. `dagger<T>()` (`org.koin.android.dagger.dagger`)
returns a Hilt `@EntryPoint` interface `T` — not the binding: call its
accessor. It needs `androidContext(...)` in `startKoin`. Gradle:
`references/gradle.md`.

```kotlin
@EntryPoint
@InstallIn(SingletonComponent::class)
interface UserDataEntryPoint {
    fun userDataRepository(): UserDataRepository
}

// Compiler Plugin DSL
val settingsModule = module {
    single { dagger<UserDataEntryPoint>().userDataRepository() }
    viewModel<SettingsViewModel>()
}

// Annotations — the Compiler Plugin passes the current Scope to a Scope parameter
@Module @Configuration @ComponentScan("com.acme.feature.settings")
class SettingsModule {
    @Singleton
    fun userDataRepository(scope: Scope): UserDataRepository =
        scope.dagger<UserDataEntryPoint>().userDataRepository()
}
```

One direction: the library lets Koin read Hilt, not the reverse. Fallback
without the library: `EntryPointAccessors.fromApplication(context, UserDataEntryPoint::class.java)`
in a `@Singleton fun` taking `context: Context`.

## Dagger 2 (no Hilt)

`dagger<T>()` relies on Hilt's `EntryPoints` — it doesn't apply. Expose the
binding on the app's own `@Component`, keep the component on the
`Application`, and read it from a `@Singleton fun`:

```kotlin
@Singleton
@Component(modules = [DataModule::class])
interface AppComponent {
    fun userDataRepository(): UserDataRepository
}

@Module @Configuration @ComponentScan("com.acme.feature.settings")
class SettingsModule {
    @Singleton
    fun userDataRepository(context: Context): UserDataRepository =
        (context.applicationContext as App).appComponent.userDataRepository()
}
```

Migrating: remove each accessor from `AppComponent` with its bridge.

**KMP** — common code has no `Application` to cast: keep the component in a
holder set by the shared start function before `startKoin` (`MetroBridge` in
"Metro" below — same shape).

## Metro

No bridge library. The consumer feature declares the bindings it needs on an
accessor interface contributed to the graph, the graph is kept in a holder set
before `startKoin`, and the feature's bridge module reads it:

```kotlin
// :feature:settings — merged into AppGraph by Metro
@ContributesTo(AppScope::class)
interface SettingsMetroAccessors {
    val userDataRepository: UserDataRepository
}

// a module every feature sees
object MetroBridge { lateinit var graph: Any }

// :feature:settings — TODO Koin migration: delete each fun when its binding moves
@Module
class MetroBridgeModule {
    @Singleton   // @Factory when the Metro binding has no @SingleIn
    fun userDataRepository(): UserDataRepository =
        (MetroBridge.graph as SettingsMetroAccessors).userDataRepository
}

@Module(includes = [MetroBridgeModule::class]) @Configuration @ComponentScan("com.acme.feature.settings")
class SettingsModule

// commonMain — shared start: the graph first, then Koin
@KoinApplication object KoinApp

fun initApp(appGraph: AppGraph) {
    MetroBridge.graph = appGraph
    startKoin<KoinApp>()
}
```

Metro reads Koin: the provider of "The other direction" below, as a `@Provides`
in a `@BindingContainer @ContributesTo(AppScope::class)`.

## Toothpick and Kodein — a scope helper

A small `Scope` extension delegating to the live container, used like
`dagger<T>()`:

```kotlin
// Toothpick
inline fun <reified T> Scope.toothpick(scopeName: Any): T =
    Toothpick.openScope(scopeName).getInstance(T::class.java)

// Kodein — legacyDI is the app's live DI container
inline fun <reified T : Any> Scope.kodein(): T = legacyDI.direct.instance()

val settingsModule = module {
    single { toothpick<UserDataRepository>(AppScope::class.java) }   // or kodein<UserDataRepository>()
}
```

Annotations: the same call in a `@Singleton fun` taking `scope: Scope`.

## The other direction — old container reads Koin

Needed only when a binding still in the old container depends on one already
in Koin. Its provider reads Koin's global context:

```kotlin
@Provides fun analytics(): Analytics = KoinPlatform.getKoin().get()   // org.koin.mp.KoinPlatform
```

Koin must be started before that provider first runs. Prefer migrating
leaf-first so this direction isn't needed.

## Two containers at startup

The `Application` starts both, the old container first, then Koin:

```kotlin
@HiltAndroidApp
@KoinApplication
class App : Application() {
    override fun onCreate() {
        super.onCreate()                              // Hilt graph built here
        startKoin<App> { androidContext(this@App) }   // org.koin.plugin.module.dsl.startKoin
    }
}
```

Dagger 2: build the component (`appComponent = DaggerAppComponent.factory().create(this)`)
before `startKoin`. Toothpick / Kodein: open the root scope / create the `DI`
before `startKoin`. Bridges resolve lazily, on first use — a bridge marked
`createdAtStart` needs the old graph ready when `startKoin` runs.
