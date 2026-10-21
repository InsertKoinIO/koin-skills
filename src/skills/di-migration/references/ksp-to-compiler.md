# Koin KSP Annotations → Koin Compiler Plugin Migration Reference

> **Setup & versions** — Gradle: `references/gradle.md` · versions: `references/rules.md` §3 · exact syntax: `references/koin-annotations.md` / `references/koin-compiler-plugin-dsl.md`.

## Table of Contents
1. [Progressive Migration](#progressive-migration)
2. [Why Migrate](#why-migrate)
3. [What Changes Overview](#what-changes-overview)
4. [KSP Removal Checklist](#ksp-removal-checklist)
5. [Gradle Migration](#gradle-migration)
6. [Annotation Changes](#annotation-changes)
7. [DSL Syntax Changes](#dsl-syntax-changes)
8. [Module Declaration Changes](#module-declaration-changes)
9. [ViewModel Changes](#viewmodel-changes)
10. [New Features](#new-features)
11. [KMP Migration](#kmp-migration)
12. [Multi-Module Projects](#multi-module-projects)
13. [Compile-Time Safety](#compile-time-safety)
14. [Configuration Options](#configuration-options)
15. [Common Pitfalls](#common-pitfalls)
16. [Verification Checklist](#verification-checklist)

---

## Progressive Migration

1. **Whole project, once (Step 3)** — KSP for Koin out, Compiler Plugin + BOM
   in, for every Gradle module together: Koin KSP and the Compiler Plugin can't
   share a build. The existing annotations keep working.
2. **Module by module (loop)** — per Gradle module: imports, `.module` call
   sites, scope annotations and the discovery triad, validated before the next.

Nothing is rewritten in place in one pass.

## Why Migrate

Projects using `koin-annotations` + `koin-ksp-compiler` (KSP-based) benefit from the Koin Compiler Plugin:

- **No KSP dependency** — removes `com.google.devtools.ksp` Gradle plugin entirely
- **No `build/generated/ksp/` files** — nothing to add to source sets
- **Faster builds** — runs as part of standard Kotlin compilation, no separate KSP pass
- **Full KMP support** — all targets (JVM, JS, WASM, iOS, macOS, Linux, Windows) without per-target KSP boilerplate
- **Better compile-time safety** — full graph at the entry point + every resolution call site
- **Top-level function definitions** — annotate standalone functions, not just classes
- **Cleaner DSL** — `single<T>()` with reified type parameters instead of `singleOf(::T)`


## What Changes Overview

| Aspect                       | KSP-based (Before)                              | Compiler Plugin (After)                          |
|------------------------------|--------------------------------------------------|--------------------------------------------------|
| Gradle plugin                | `com.google.devtools.ksp`                        | `io.insert-koin.compiler.plugin`                 |
| Compiler dependency          | `ksp("io.insert-koin:koin-ksp-compiler")`        | Included via plugin                              |
| Annotations library          | `io.insert-koin:koin-annotations:1.x/2.x`       | `io.insert-koin:koin-annotations` via `koin-bom` |
| Generated files              | `build/generated/ksp/*.kt` files                 | **None**                                         |
| DSL style                    | `singleOf(::MyClass)`                            | `single<MyClass>()`                              |
| Module import                | `import org.koin.ksp.generated.module`            | No special import needed                         |
| KMP setup                    | Per-target `ksp(...)` + task hacks               | Single plugin declaration                        |
| Kotlin version               | K1 and K2                                        | **K2 only** (Kotlin ≥ 2.3.20)                     |
| Top-level functions          | Not supported                                    | Fully supported with `@ComponentScan`            |
| Compile safety               | Partial (KSP-time)                               | Full graph + call sites                          |
| @KoinViewModel import        | `org.koin.android.annotation.KoinViewModel`      | `org.koin.core.annotation.KoinViewModel`         |

### What stays the same (no code changes)

- `@Single`, `@Singleton`, `@Factory`, `@Scoped` — migrated output emits `@Singleton` instead of `@Single`
- `@KoinViewModel` (just import path changes)
- `@Named("qualifier")`, `@Qualifier`
- `@InjectedParam`, `@Property("key")`, `@PropertyValue`
- `@Module`, `@Module(includes = [...])`
- `@ComponentScan("package")`
- `binds = [Interface::class]` parameter
- `createdAtStart = true` parameter

What changes beyond imports: `AppModule().module` (KSP generated, `org.koin.ksp.generated`)
→ `@KoinApplication` + `@Configuration` discovery, or `startKoin { module<AppModule>() }`;
a `@Scope` used alone gets `@Scoped` next to it — `@Scope` alone is not a
definition (`references/scopes.md`).

## KSP Removal Checklist

Sub-steps of Step 3 (Gradle, whole project) and the per-module loop.

### 1. Verify Prerequisites

1. **Kotlin version**: 2.3.20 minimum (K2 compiler)
   ```bash
   # Check your Kotlin version in gradle.properties or build.gradle.kts
   grep -r "kotlin" gradle.properties | grep version
   ```
2. **Koin version**: Must upgrade to the version in `references/rules.md` §3
3. If you cannot upgrade Kotlin to 2.3.20, **stay on KSP** and say so — the compiler plugin requires it (`references/rules.md` §3)

### 2. Update Gradle Configuration (Step 3, all modules)

**In each module's `build.gradle.kts`:**

```kotlin
// REMOVE these:
plugins {
    // id("com.google.devtools.ksp") version "..."  ← REMOVE (if only used for Koin)
}

dependencies {
    // ksp("io.insert-koin:koin-ksp-compiler:...")  ← REMOVE
}

// REMOVE the ksp { } block:
// ksp {
//     arg("KOIN_USE_COMPOSE_VIEWMODEL", "true")
//     arg("KOIN_DEFAULT_MODULE", "false")
//     arg("KOIN_CONFIG_CHECK", "true")
// }
```

Add Koin per `references/gradle.md` — Compiler Plugin, `koin-bom`, only the artifacts the project needs (KMP: shared artifacts in `commonMain`, no per-target configuration). Versions: `references/rules.md` §3.

### 3. Update Imports and Module Loading (per module)

```kotlin
// BEFORE: KSP-based
import org.koin.android.annotation.KoinViewModel
import org.koin.ksp.generated.module

startKoin { modules(AppModule().module) }

// AFTER: Compiler Plugin
import org.koin.core.annotation.KoinViewModel

@KoinApplication            // AppModule carries @Module @Configuration @ComponentScan
class App : Application()   // startKoin<App> { … } — org.koin.plugin.module.dsl
```

### 4. Update DSL Syntax — if the project also has DSL modules

The compiler plugin introduces reified type parameter syntax:

```kotlin
// BEFORE: constructor reference style
val myModule = module {
    singleOf(::UserRepository)
    factoryOf(::DetailPresenter)
    viewModelOf(::MainViewModel)
}

// AFTER: reified type parameter style (preferred with compiler plugin)
val myModule = module {
    single<UserRepository>()
    factory<DetailPresenter>()
    viewModel<MainViewModel>()
}
```

With qualifiers:
```kotlin
// BEFORE
singleOf(::MyService) { named("production") }

// AFTER — qualifier on the class, plain reified definition
@Named("production") class MyService(…)
single<MyService>()
```

With options:
```kotlin
// BEFORE
singleOf(::MyService) {
    named("production")
    bind<Service>()
    createdAtStart()
}

// AFTER — @Named("production") on the class
single<MyService>().withOptions {
    bind<Service>()
    createdAtStart()
}
```

### 5. Remove Generated File References

1. Delete `build/generated/ksp/` directories
2. Remove any manual source set configuration for KSP:
   ```kotlin
   // REMOVE these lines from build.gradle.kts:
   // sourceSets.named("commonMain").configure {
   //     kotlin.srcDir("build/generated/ksp/metadata/commonMain/kotlin")
   // }
   ```
3. Remove KSP task dependency hacks:
   ```kotlin
   // REMOVE:
   // tasks.matching { it.name.startsWith("ksp") ... }.configureEach { ... }
   ```

### 6. Clean Build and Verify

```bash
./gradlew clean build
```

Fix any compilation errors (see Common Pitfalls section below).

### 7. Keep Compile-Time Safety On

On by default — don't turn it off. `userLogs` shows what the plugin detects:

```kotlin
// build.gradle.kts
koinCompiler {
    compileSafety = true    // default
    userLogs = true         // see what components are detected
}
```

## Gradle Migration

### JVM/Android — Before (KSP)

```kotlin
plugins {
    id("com.google.devtools.ksp") version "2.1.21-2.0.2"
}

dependencies {
    implementation("io.insert-koin:koin-core:3.5.x")
    implementation("io.insert-koin:koin-android:3.5.x")
    implementation("io.insert-koin:koin-annotations:1.4.x")
    ksp("io.insert-koin:koin-ksp-compiler:1.4.x")
    implementation("io.insert-koin:koin-androidx-compose:3.5.x")
}

ksp {
    arg("KOIN_USE_COMPOSE_VIEWMODEL", "true")
    arg("KOIN_DEFAULT_MODULE", "false")
}
```

### JVM/Android — After (Compiler Plugin)

Add Koin per `references/gradle.md` — Compiler Plugin, `koin-bom`, only the artifacts the project needs (KMP: shared artifacts in `commonMain`, no per-target configuration). Versions: `references/rules.md` §3.

### KMP — Before (KSP) — Complex!

```kotlin
plugins {
    id("com.google.devtools.ksp") version "2.1.21-2.0.2"
}

kotlin {
    sourceSets.named("commonMain").configure {
        kotlin.srcDir("build/generated/ksp/metadata/commonMain/kotlin")
    }
}

dependencies {
    commonMainImplementation("io.insert-koin:koin-core:3.5.x")
    commonMainImplementation("io.insert-koin:koin-annotations:1.4.x")
    // Per-target KSP — every target needs this!
    add("kspCommonMainMetadata", "io.insert-koin:koin-ksp-compiler:1.4.x")
    add("kspAndroid", "io.insert-koin:koin-ksp-compiler:1.4.x")
    add("kspIosX64", "io.insert-koin:koin-ksp-compiler:1.4.x")
    add("kspIosArm64", "io.insert-koin:koin-ksp-compiler:1.4.x")
    add("kspIosSimulatorArm64", "io.insert-koin:koin-ksp-compiler:1.4.x")
}

// Task dependency hack
tasks.matching { it.name.startsWith("ksp") && it.name != "kspCommonMainKotlinMetadata" }
    .configureEach { dependsOn("kspCommonMainKotlinMetadata") }
```

### KMP — After (Compiler Plugin) — Simple!

Add Koin per `references/gradle.md` — Compiler Plugin, `koin-bom`, only the artifacts the project needs (KMP: shared artifacts in `commonMain`, no per-target configuration). Versions: `references/rules.md` §3.

## Annotation Changes

### Unchanged annotations (no modifications)

```kotlin
// These keep working (migrated output: @Singleton, never @Single):
@Singleton
class UserRepository(private val api: ApiService, private val dao: UserDao)

@Singleton
class AppDatabase(private val context: Application)

@Singleton(createdAtStart = true)
class AnalyticsInitializer(private val context: Application)

@Singleton(binds = [UserRepository::class])
class UserRepositoryImpl(private val api: ApiService) : UserRepository

@Factory
class DetailPresenter(private val repo: ItemRepository)

@Scope(UserSession::class)
@Scoped
class UserPreferences(private val db: AppDatabase)

@Singleton
class MyRepo(@Named("io") private val dispatcher: CoroutineDispatcher)

@Module
@ComponentScan("com.myapp.data")
class DataModule

@Module(includes = [NetworkModule::class, DatabaseModule::class])
class AppModule
```

### Import path change: @KoinViewModel

Only the import changes — the class, `@InjectedParam` and the call sites
(`koinViewModel { parametersOf(…) }`, `by viewModel { parametersOf(…) }`) stay the same:

```kotlin
// BEFORE (KSP)
import org.koin.android.annotation.KoinViewModel
// AFTER (Compiler Plugin)
import org.koin.core.annotation.KoinViewModel
```

### Generated `.module` → discovery

```kotlin
// BEFORE (KSP) — generated extension
import org.koin.ksp.generated.module

startKoin {
    modules(AppModule().module)
}

// AFTER (Compiler Plugin) — @KoinApplication discovers @Configuration modules
@KoinApplication
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin<App> { androidContext(this@App) }   // org.koin.plugin.module.dsl
    }
}

// Escape hatch (variants, test overrides) — explicit loading
startKoin { module<AppModule>() }                      // or modules(A::class, B::class)
```

## DSL Syntax Changes

Same mapping as `references/dsl-to-compiler.md` → "Core DSL Mapping" (owner of the classic / constructor → Compiler Plugin DSL table).

**Note**: The old `singleOf(::Class)` syntax still works if you prefer not to change DSL code immediately. The compiler plugin supports both styles.

## Module Declaration Changes

```kotlin
// BEFORE (KSP): Module with generated module extension
@Module
@ComponentScan("com.myapp.network")
class NetworkModule

import org.koin.ksp.generated.module
startKoin {
    modules(NetworkModule().module)
}

// AFTER (Compiler Plugin): the discovery triad, no module list
@Module
@Configuration
@ComponentScan("com.myapp.network")
class NetworkModule

startKoin<App> { androidContext(this@App) }   // App is @KoinApplication
```

## ViewModel Changes

Only the `@KoinViewModel` import changes — see "Import path change: @KoinViewModel" above.

## New Features

### Top-Level Function Definitions

The compiler plugin supports annotations on top-level functions (not possible with KSP):

```kotlin
// Top-level functions — discovered by @ComponentScan
@Singleton
fun provideDatabase(): DatabaseService = PostgresDatabase()

@Factory
fun provideCache(db: DatabaseService): CacheService = RedisCache(db)

@Singleton
@Named("http")
fun provideHttpClient(): NetworkClient = OkHttpClient()

// Module scans its own package (references/rules.md §7)
@Module
@Configuration
@ComponentScan("com.example.app")
class AppModule
```

### @KoinApplication for Automatic Module Injection

```kotlin
// Define application entry point with module list
@KoinApplication(modules = [AppModule::class, NetworkModule::class])
object MyApp

// Modules are auto-injected — no manual module list
fun main() {
    startKoin<MyApp>()
}
```

### @Configuration for Cross-Module Discovery

```kotlin
// In feature module — marks module as discoverable
@Module
@ComponentScan
@Configuration
class FeatureModule

// In app module — auto-discovers @Configuration modules
@KoinApplication
object MyApp

startKoin<MyApp>()  // FeatureModule automatically included
```

### @Monitor for Kotzilla Observability

```kotlin
@Monitor
@Singleton
class UserRepository(private val api: ApiService) {
    fun getUsers(): List<User> { ... }
}
// Compiler Plugin wraps each public function body with Kotzilla trace calls
```

Keep existing `@Monitor` as is. Never add it unless the user accepted Kotzilla
(handoff rules in `references/kotzilla.md`); without the Kotzilla SDK on the
classpath the plugin warns (`KOIN-M001`) and monitoring is off.

## KMP Migration

The biggest improvement: no per-target KSP boilerplate.

```kotlin
// commonMain — works on ALL Kotlin targets
@Module
@ComponentScan("com.myapp.shared")
class SharedModule

@Singleton
class CommonRepository(private val api: ApiClient)

// Platform modules with expect/actual
// commonMain
@Module
expect class PlatformModule

// androidMain
@Module
actual class PlatformModule {
    @Singleton
    fun providePlatform(): Platform = AndroidPlatform()
}

// iosMain
@Module
actual class PlatformModule {
    @Singleton
    fun providePlatform(): Platform = IosPlatform()
}
```

## Multi-Module Projects

### Before (KSP): Every module needed KSP config

```kotlin
// feature/build.gradle.kts
plugins {
    id("com.google.devtools.ksp")
}
dependencies {
    implementation("io.insert-koin:koin-annotations:1.4.x")
    ksp("io.insert-koin:koin-ksp-compiler:1.4.x")
}
```

### After (Compiler Plugin): Just apply the plugin

Add Koin per `references/gradle.md` — Compiler Plugin, `koin-bom`, only the artifacts the project needs (KMP: shared artifacts in `commonMain`, no per-target configuration). Versions: `references/rules.md` §3.

### Cross-Module Discovery with @Configuration

Default — each Gradle module's root carries the triad, the app discovers them:

```kotlin
// :feature-auth module
@Module
@Configuration
@ComponentScan("com.myapp.auth")
class AuthModule

// :feature-profile module
@Module
@Configuration
@ComponentScan("com.myapp.profile")
class ProfileModule

// :app module — discovers all @Configuration modules
@KoinApplication
object MyApp
```

Keep existing `@Configuration("label")` / `@KoinApplication(configurations = [...])`
labels as they are; adding new ones is advanced — ask first (`references/rules.md` §7).

## Compile-Time Safety

Two checks: the full graph at `startKoin<T>()` / `@KoinApplication`, and every
`get` / `inject` / `koinViewModel` call site — `references/rules.md` §6.
`includes` and `@Configuration` only decide which modules join the graph.

### What Gets Validated

| Scenario                                   | Result                                          |
|--------------------------------------------|-------------------------------------------------|
| Non-nullable param, no definition          | **ERROR**                                       |
| Nullable param (`T?`), no definition       | OK — uses `getOrNull()`                         |
| Param with default value, no definition    | OK — uses Kotlin default (when `skipDefaultValues=true`) |
| `@InjectedParam`, no definition            | OK — provided at runtime via `parametersOf()`   |
| `@Property("key")` param                  | OK — property injection                         |
| `@Provided` type, no definition            | OK — externally provided                        |
| `List<T>` param                           | OK — `getAll()` returns empty if none           |
| `Lazy<T>`, no definition for T            | **ERROR** — validates inner type                |
| `@Named("x")` param, no matching qualifier | **ERROR** — with hint if unqualified exists     |
| Scoped dependency from wrong scope         | **ERROR**                                       |

## Configuration Options

```kotlin
// build.gradle.kts
koinCompiler {
    // Enable user-facing logs (component detection, DSL definitions)
    userLogs = true                 // Default: false

    // Enable debug logs (internal plugin processing details)
    debugLogs = true                // Default: false

    // Enable unsafe DSL checks (validates create() usage)
    unsafeDslChecks = true          // Default: true

    // Skip injection for parameters with default values
    skipDefaultValues = true        // Default: true

    // Enable compile-time dependency safety checks
    compileSafety = true            // Default: true
}
```

## Common Pitfalls

### 1. Using Kotlin < 2.3.20

```
Error: The Koin Compiler Plugin requires Kotlin ≥ 2.3.20 (K2 compiler)
```
Upgrade Kotlin first (`references/rules.md` §3). If you can't, stay on KSP and say so.

### 2. Forgetting to update @KoinViewModel import

```kotlin
// WRONG — old import will not resolve
import org.koin.android.annotation.KoinViewModel

// RIGHT
import org.koin.core.annotation.KoinViewModel
```

### 3. Leftover KSP generated imports

```kotlin
// WRONG — KSP import no longer needed
import org.koin.ksp.generated.module

// RIGHT — @KoinApplication discovery; explicit loading: startKoin { module<AppModule>() }
// (org.koin.plugin.module.dsl). Never AppModule().module
```

### 4. Keeping KSP plugin when not needed

Remove `com.google.devtools.ksp` if only Koin used it — keeping both plugins can conflict. Keep KSP only if **other** processors need it (Room, Moshi…).

### 5. Version mismatch

Don't keep an old `koin-annotations` version (1.x / 2.x — the KSP artifacts) next to the Compiler Plugin. Let the `koin-bom` resolve `koin-annotations` with the rest of Koin (`references/rules.md` §2).

### 6. KMP per-target KSP declarations left behind

```kotlin
// REMOVE all of these:
dependencies {
    add("kspCommonMainMetadata", "io.insert-koin:koin-ksp-compiler:...")
    add("kspAndroid", "io.insert-koin:koin-ksp-compiler:...")
    add("kspIosX64", "io.insert-koin:koin-ksp-compiler:...")
}

// REMOVE source set hacks:
// sourceSets.named("commonMain").configure {
//     kotlin.srcDir("build/generated/ksp/metadata/commonMain/kotlin")
// }
```

## Verification Checklist

- [ ] Kotlin at 2.3.20 or later (K2)
- [ ] Koin upgraded per `references/rules.md` §3
- [ ] `com.google.devtools.ksp` plugin removed (or only kept for non-Koin processors)
- [ ] `ksp("io.insert-koin:koin-ksp-compiler")` dependency removed
- [ ] `ksp { }` block removed or cleaned of Koin-specific args
- [ ] `io.insert-koin.compiler.plugin` plugin added
- [ ] `koin-annotations` resolved by the `koin-bom` — no pinned version
- [ ] `@KoinViewModel` import changed to `org.koin.core.annotation`
- [ ] `import org.koin.ksp.generated.module` and every `AppModule().module` removed
- [ ] Per-target KSP declarations removed (KMP projects)
- [ ] KSP source set hacks removed (KMP projects)
- [ ] `build/generated/ksp/` directory deleted
- [ ] Clean build succeeds: `./gradlew clean build`
- [ ] No `checkModules()` / `verify()` tests left — compile-time verification replaces them
- [ ] ViewModel injection verified in Activities, Fragments, Composables
- [ ] Scoped bindings verified — every `@Scope` paired with `@Scoped` (or a scope archetype)
