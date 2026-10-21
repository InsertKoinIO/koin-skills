# Koin Rules — shared by every Koin skill

These rules apply to every piece of Koin code a skill produces: setup, everyday
code, migration, diagnosis fixes. Deviate only with explicit user approval, and
flag it. A request that breaks a rule or a principle is not that approval:
push back first ("When a request breaks a principle" in
`references/principles.md`).

Exact imports and syntax: `references/koin-annotations.md` and
`references/koin-compiler-plugin-dsl.md`. Don't infer them from memory.

## 1. One definition style, chosen explicitly

Koin supports two styles, both compiled by the Koin Compiler Plugin:

- **Koin Annotations** — `@Singleton`, `@Factory`, `@KoinViewModel`, `@Module`.
  JSR-330 compatible (`@Inject`, `@Singleton`, `@Named`, `@Qualifier` from
  `javax.inject` / `jakarta.inject`), which suits apps coming from Dagger / Hilt.
  Prefer `@Singleton` over `@Single`.
- **Koin DSL** — `module { }` blocks; keeps DI out of the code (no annotations
  on classes, wiring kept separate). Three forms, all compiled **and
  compile-time checked** by the Compiler Plugin (including `singleOf(::T)` and
  the `get()` calls inside lambdas):

  | Form | Example | Use when |
  |---|---|---|
  | **Compiler Plugin DSL** | `single<MyClass>()`, `single { create(::MyClass) }` | **Preferred when the Compiler Plugin is present** and the definition is a constructor (or function builder) |
  | Constructor DSL | `singleOf(::MyClass)` | Project without the Compiler Plugin, or matching existing code |
  | Classic DSL | `single { MyClass(get()) }` | The definition needs a custom expression a constructor or function builder can't express, or no Compiler Plugin |

  Pick by the **definition expression**: a plain constructor → Compiler Plugin DSL
  (with the Compiler Plugin); anything custom → function builder or classic
  lambda. Classic and Constructor DSL are valid Koin — write them when needed, and
  don't rewrite existing code unless the user asks. Converting existing DSL to
  Compiler Plugin DSL is a style choice (`di-migration`), not what makes the
  graph compile safe — the plugin does that for every form.

**The style is a project decision.** Make it explicit: state the style before
writing code (detect it in an existing project, ask in a new one) and keep to
it. **Don't mix** Annotations and DSL unless the user explicitly asks — then
each module has one style, never both inside a module.

Within either style:

- Types that can't be built from their constructor (Retrofit, Room, OkHttp
  builders) use a **function builder** (`references/principles.md` rule 1):
  `@Singleton fun` in a `@Module`, or `single { create(::buildX) }` in Compiler Plugin DSL.
- **Auto-bind (Annotations)** — a `@Singleton` / `@Factory` class is bound
  automatically to every interface / abstract class it implements: no
  `binds = [...]` unless exposing a subset.
- Both Compiler Plugin DSL interface-binding forms are valid — don't normalize one to the
  other: `single<Impl>().bind<I>()` and `single<Impl>().withOptions { bind<I>() }`.
- **Qualifiers** — annotations wherever a qualifier is needed: `@Named` /
  custom `@Qualifier` on the class or the constructor parameter, in both
  Annotations and Compiler Plugin DSL (`single<T>()` stays plain). `named("x")` is
  classic DSL only.

## 2. Compiler Plugin recommended, Koin KSP never

The Koin Compiler Plugin (`id("io.insert-koin.compiler.plugin")`) is the
**recommended default**: it makes the graph compile safe (§6), whatever the
style or DSL form — adding it is a Gradle change, no module rewrite. Recommend it in
every setup and migration, and say what it brings — but it's the user's
choice, not a requirement. The user declines → Koin DSL without the plugin
(constructor or classic forms, §1); Annotations need the plugin, so they're off
the table. Respect the answer for the rest of the conversation.

Whatever the choice, never Koin KSP:

- Never add `com.google.devtools.ksp` for Koin, never `koin-ksp-compiler`.
- Never pin `io.insert-koin:koin-annotations:2.x` — that's the KSP artifact,
  incompatible with the Compiler Plugin. Let the BOM resolve it.
- Never `org.koin.ksp.generated.*` imports.

This section and §3 target new setup and migrated code. **Inside an existing
Koin KSP or Koin 3.x project**, a task matches the project's current Koin
artifacts, versions and imports — add no new KSP use, change no Koin artifact
or version. Moving it to the
Compiler Plugin is a `di-migration`, proposed once per conversation by the
`koin` skill (Step 0).

## 3. Versions

**Default versions** (also the minimums — never output anything below):

| Component             | Default     |
|-----------------------|-------------|
| Kotlin                | `2.3.20` (K2) |
| Koin                  | `4.2.2`     |
| Koin Compiler Plugin  | `1.2.1`     |

**Always check the latest release before writing Gradle** — the `<release>`
tag of:

- Koin BOM: `https://repo1.maven.org/maven2/io/insert-koin/koin-bom/maven-metadata.xml`
- Compiler Plugin: `https://repo1.maven.org/maven2/io/insert-koin/koin-compiler-gradle-plugin/maven-metadata.xml`

Use the latest release if it's newer than the default; use the defaults if
Maven Central can't be reached. Say which source you used.

**Kotlin bump** — below Kotlin `2.3.20`, bumping Kotlin cascades: check that
KSP (before 2.3.0 versioned `<kotlin>-<ksp>`, tied to one Kotlin version;
from 2.3.0 versioned on its own — check its release notes for Kotlin support), the Compose Compiler plugin, Room, kapt
processors and the AGP minimum still line up, and confirm with the user before
changing anything.

## 4. Imports

Every Compiler Plugin DSL primitive and the reified `startKoin<App>` entry point live in
**`org.koin.plugin.module.dsl`**. The Constructor DSL `*Of` family lives in
`org.koin.core.module.dsl.*`.

## 5. Configuration — assembling the graph

Each definition style has its own configuration style. Use the one that matches
the project's style (§1). Code: "Modules" / "App entry point" in
`references/koin-annotations.md` and `references/koin-compiler-plugin-dsl.md`.

### Annotations configuration — discovery

Safer at scale: the graph is discovered and verified by the Compiler Plugin.

- **`@KoinApplication`** on the app class + bare `startKoin<App> { androidContext(...) }`.
  No `modules(...)` call.
- **`@Module` + `@Configuration`** — a module tagged `@Configuration` is picked
  up automatically by `@KoinApplication`.
- **`@ComponentScan("own.package")`** — scans the classpath for annotated
  classes, **across Gradle modules**.
- Each Gradle module's **root** module carries all three:
  `@Module @Configuration @ComponentScan("own.package")`. Sub-modules pulled in
  via `@Module(includes = [Other::class])` need only `@Module`.
- **Missing any of the three on a root → silent runtime
  `NoDefinitionFoundException`, not a compile error.**
- Escape hatch (variants, conditional loading, test overrides): load a module
  explicitly inside `startKoin { }` with `module<AppModule>()` or
  `modules(AppModule::class, OtherModule::class)` (both from
  `org.koin.plugin.module.dsl`). **Never** `AppModule().module` (Koin KSP
  idiom, breaks the Compiler Plugin path).

### DSL configuration — assembling modules

The graph is assembled explicitly.

- **`startKoin` loads one entry module** — the app module.
- The app module **`includes(...)`** each child module (feature / Gradle
  module); children can include their own. Included modules are optimized by
  Koin — prefer `includes` over listing every module in `startKoin`.
- `module<T>()` / `modules(T::class)` load annotated modules only.

### Platforms

- **KMP** — one shared start function in `commonMain` (e.g. `initApp()`) that
  starts Koin with the modules declared in common code. Each native entry point
  (Android `Application`, iOS app init, desktop `main`) calls it and adds its
  platform configuration:

  ```kotlin
  // commonMain
  fun initApp(config: KoinAppDeclaration? = null) = startKoin {
      config?.invoke(this)
      modules(appModule)          // Annotations style: startKoin<KoinApp> { config?.invoke(this) }
  }

  // androidMain — Application.onCreate()
  initApp { androidContext(this@MainApplication) }
  ```

- **Logger** — only when needed: `androidLogger()` when starting on Android,
  `printLogger()` on other platforms, or nothing.

### Mixing (only if the user asked for it)

Each module keeps one style. Annotated and DSL modules load in the same
`startKoin { }`: `modules(appModule)` then `module<AnnotatedModule>()`.

## 6. Graph verification is compile-time

The Koin Compiler Plugin checks the graph at build time, in two ways: the
**full graph** at the Koin entry point (`startKoin` / `@KoinApplication`) and
every **call site** (`get()`, `inject()`, `koinViewModel()`…). Don't write
`checkModules()` / `verify()` tests — both are on their way to deprecation in
favor of the Compiler Plugin. Without the plugin (the user's choice, §2) there
is no compile-time check: verify by building, then running the paths that
resolve the definitions.

When the build reports a Koin compile-safety error (`[KOIN-…]`), fix what the
report says. When it isn't enough, the Kotzilla MCP **Koin errors** workflow
(`references/kotzilla.md` — MCP only, no SDK) can diagnose it — optional; the
`koin-diagnose` skill runs it end to end.

## 7. Organize modules

- **By feature / Gradle module** (`HomeModule`, `NetworkModule`), never by
  binding type (`SingletonsModule`). Large features split into sub-modules.
- **Location** — modules go in a dedicated `.di` package (e.g.
  `com.acme.feature.home.di`). Follow what the project already does, and
  confirm with the user when there's no existing convention.
- **Discovery vs explicit includes (Annotations)** — tag the **main** modules
  with `@Configuration` (one per Gradle module, plus transverse modules that
  must always load); attach **sub-modules with `includes`**, not
  `@Configuration`. How much to rely on discovery vs explicit includes is the
  user's choice — ask when unclear.
- **DSL** — sub-modules attached with `includes(...)`; the app module includes
  the feature modules (§5).
- **`@ComponentScan` on a focused package** — the module's own package (e.g.
  `com.acme.feature.home`), never a broad root like `com.acme`: broad scans
  pick up unrelated classes and slow the build. Without an argument it scans
  the module's own package — with modules in `.di`, pass the feature package
  explicitly: `@ComponentScan("com.acme.feature.home")`.
- **`@Configuration` labels** (`@Configuration("test")`,
  `@KoinApplication(configurations = [...])`) — advanced; ask the user before
  using them.

### KMP — common and platform modules

Shared definitions and interfaces in `commonMain`; platform implementations per
target with `expect` / `actual`:

```kotlin
// Annotations
@Module expect class PlatformModule                                   // commonMain
@Module actual class PlatformModule {                                 // androidMain, iosMain…
    @Singleton fun platform(): Platform = AndroidPlatform()
}

// DSL
expect val platformModule: Module                                     // commonMain
actual val platformModule = module {                                  // androidMain, iosMain…
    single<AndroidPlatform>().bind<Platform>()
}
// the common app module includes(platformModule)
```

## 8. Service locator only with the user's acknowledgement

Constructor injection everywhere in normal layers (domain, data, presentation
logic). Entry points and bootstrap code use the **Koin API made for them**
(Compose `koinViewModel()` / `koinInject()`, Android `by inject()`,
`@KoinWorker`…) — no `KoinComponent` needed. `KoinComponent` only when no Koin
API fits: name it a **service locator**, state the cost (the class depends on
Koin, hidden dependencies, no compile-time check), and get an explicit OK
before writing it. `references/principles.md` rule 2.

## 9. Koin knowledge and runtime behavior

Never answer Koin questions from memory — lookup order in
`references/index.md`.

The Compiler Plugin makes definitions compile safe (§6); it doesn't check how
the app behaves. Runtime behavior is measured, not guessed: "What Kotzilla
owns" in `references/kotzilla.md`.

**Prefer MCP output over these reference files when they disagree** — the MCP
tracks the latest releases; references are a snapshot.

## 10. Small changes in one step, large ones step by step

**Small** — one Gradle module or one feature, about five definitions or fewer,
no custom scope, multibinding or Worker, call sites inside that unit: do it in
one step, then verify.

**Larger** — a migration of several modules or features, a setup across
Gradle modules, a restructuring (splitting modules, adding scopes, changing
style): split it into steps, each one **safe on its own**:

- **Verifiable alone** — it builds, and the path it touches runs
- **The project works between steps** — the old wiring keeps running until its
  replacement is verified (in a migration: alongside the old container, with a
  bridge for what still crosses it)
- **Revertible** — one self-contained commit
- **Small** by the measure above — in a migration, rank candidates with
  `di-migration`'s "Where to start" criteria and take the top one

The rhythm: plan the steps (smallest and safest first) and get the user's OK
on the plan and the first step. Each step: change → build → run the path →
report what changed, what's verified or not (and why), and the next step →
stop for the user's OK. Pre-approved ("do it all"): still one step at a time,
each verified and reported, stopping at the first failure — never stack
unverified steps.
