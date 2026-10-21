# Changelog

All notable changes to the **koin** plugin (successor of `koin-migration`) are documented in this file.
This project follows [Semantic Versioning](https://semver.org/).

## [2.0.0] - 2026-10-21

New plugin **`koin`**, the official Koin skills, succeeding `koin-migration` (1.0.0, migration only).
Install: `/plugin marketplace add InsertKoinIO/koin-skills` then `/plugin install koin@koin-skills`.

### Added
- Four skills:
  - `koin-setup`: set up Koin in a new or legacy project, or next to a DI container the user keeps
  - `koin`: write Koin code in the project's style, and push back on DI mistakes
  - `di-migration`: migrate from Hilt, Dagger, Toothpick, Kodein, **Metro**, Koin 3.x, Koin DSL or Koin KSP, progressively, module by module
  - `koin-diagnose`: Koin errors and crashes, and app behavior (static suspects, proof with Kotzilla)
- Shared references used by every skill: rules, DI principles, Gradle, entry points, scopes, testing, Annotations, Compiler Plugin DSL, bridging, Kotzilla
- Bridging with an existing container (`bridging.md`): `koin-dagger-bridge` for Hilt (`dagger<T>()` on an `@EntryPoint`, both styles), Dagger 2, Toothpick, Kodein and Metro; two containers at startup
- Kotzilla MCP Server bundled with the plugin (`plugin:koin:kotzilla`), inactive until the user signs in through `/mcp`
- Scopes: "Choose the scope": no scope, then a scope archetype (ViewModel preferred, Activity, retained Activity, Fragment), a custom scope only when none fits; scope with a runtime value; scope test recipe
- Startup values (`androidContext`, `koin.declare` + `@Provided`, `@Property`); keyed ViewModels in Compose
- One multibinding pattern for every source: each element a `@Named` definition bound to `T`, consumers inject `List<T>`

### Changed
- Kotzilla is always proposed with its purpose, never forced: a decline holds for the whole conversation, the user signs in and approves installs, and every skill works without it
- Compile safety: the Compiler Plugin checks every DSL form, Classic included (full graph at the entry point + every call site). Converting to Compiler Plugin DSL is optional; the compile-safety proposal is "add the Compiler Plugin", not a rewrite
- DSL terminology aligned with insert-koin.io: **Compiler Plugin DSL** `single<T>()` (was "Safe DSL"), **Constructor DSL** `singleOf(::T)` (was "Autowire DSL"), **Classic DSL** `single { T(get()) }`
- Minimum versions: Kotlin 2.3.20, Koin 4.2.2, Compiler Plugin 1.2.1, with the latest checked on Maven Central
- Graph verification is compile-time; `checkModules()` / `verify()` no longer emitted
- Compose: `koin-compose` + `koin-compose-viewmodel`; `KoinContext` removed (deprecated)
- Repo: sources in `src/`, complete skills generated in `skills/` (committed, the installed plugin); release asset `koin-plugin.zip`; evals moved to a separate repo

### Fixed
- Annotated modules load with `startKoin { module<T>() }` or `modules(T::class)`; `modules(module<T>())` doesn't compile
- Android scope archetypes and `@KoinWorker` are in `org.koin.android.annotation`; `.bind<T>()` is `org.koin.dsl.bind`; custom qualifiers use `qualifier<T>()`
- `koin-dagger-bridge` is Hilt-only and one-way (Koin reads Hilt); the old framework is removed only at the end of a migration
- Dagger `@Component.Factory` / `@Component.Builder` inputs map to startup values, not `@InjectedParam`
- `Provider<T>` maps to `Lazy<T>`; `Scope.get()` per call is a service locator and needs the user's OK
- Compiler Plugin DSL without the Compiler Plugin fails at runtime, not "compiles without checks"

## [1.0.0] - 2026-04-14

Initial release.

### Migration paths
- Hilt (+ Dagger) → Koin 4.x + Koin Compiler Plugin (annotations output)
- Dagger 2 (no Hilt) → Koin 4.x + Koin Compiler Plugin (annotations output)
- Toothpick → Koin 4.x + Koin Compiler Plugin (annotations output)
- Koin KSP Annotations → Koin Compiler Plugin (annotations preserved)
- Kodein → Koin 4.x + Koin Compiler Plugin (Safe DSL output)
- Koin 3.x → Koin 4.x Safe DSL + Koin Compiler Plugin
- Classic Koin DSL → Safe DSL + Koin Compiler Plugin

Greenfield projects and manual-DI / service-locator code are intentionally out
of scope — this skill is for framework-to-framework migration. The same output
rules apply if you follow the official Koin docs at https://insert-koin.io.

### Non-negotiable rules
- **Always target the Koin Compiler Plugin** — never Koin KSP (`koin-ksp-compiler`)
- **Minimum versions**: Kotlin ≥ `2.3.20` (K2 only), Koin ≥ `4.2.1`, Koin Compiler Plugin ≥ `1.0.0-RC1`. At Step 3, always try to resolve newer Koin and Compiler Plugin versions via Kotzilla MCP / Maven Central / GitHub releases — minimums are not targets. Confirm with the user before bumping the Compiler Plugin (RC API may shift).
- **Output style per source** (see table above) — do not emit annotations for Kodein migrations
- **Prefer `@Singleton` over `@Single`** — both are Koin Annotations, `@Singleton` reads more naturally and matches JSR-330
- **Module access**: `modules(module<AppModule>())` (reified helper), never `AppModule().module` (old KSP pattern)
- **App wiring (annotations)**: `@KoinApplication` + the **triad** on every module — `@Module` + `@Configuration` + `@ComponentScan("own.package")`; missing any silently breaks cross-Gradle-module discovery (runtime `NoDefinitionFoundException`, not a compile error)
- **App wiring (DSL)**: plain `startKoin { modules(appModule, ...) }`, no `@Configuration`
- **Safe DSL forms** — prefer `single<T>()` (reified, compiler resolves ctor) or `single { create(::T) }`; classic lambda `single { T(get()) }` is fallback only for third-party types
- **Safe DSL qualifiers** — `@Named` on the class declaration + reified `single<T>()`; do **not** write `single<T>(named("x")) { ... }` for classes you own (that's classic DSL, fallback only)
- **Kodein qualifiers** — always `@Named`, never custom `@Qualifier` annotations (preserves Kodein's string-tag semantics)

### Workflow
- **8-step per-module loop** — Inventory → Plan → Gradle → Generate → Wire → Update Sites → **Validate** → Final Cleanup
- **Ranked module selection** — leaf modules, few bindings, simple types, feature over core, self-contained call sites; defer `AppModule`, `@EntryPoint`, Workers, custom components
- **Per-module validation** runs after every module, not only at the end — build green + runtime smoke test + MCP verification + commit before next module
- **Progressive migration** — new Koin module alongside the old container; never rewrite in place; remove the old framework only when the last binding has moved

### Bridging (Koin + legacy DI coexisting)
- **Hilt (library)** — `koin-android-dagger`
- **Hilt (annotations)** — `@Singleton fun` inside a `@Module @Configuration` class using `EntryPointAccessors.fromApplication(...)`; bridge module **must** carry `@Configuration`
- **Hilt (Safe DSL)** — `Scope.dagger<T>()` helper via `EntryPoints.get(...)`
- **Dagger 2 (no Hilt)** — `AppComponent` instance on `Application` + `@Singleton fun` delegations in a `@Module @Configuration` bridge module
- **Toothpick / Kodein** — analogous function-style bridges in the per-source references
- **Dual-container Application** — `@HiltAndroidApp @KoinApplication`; `super.onCreate()` **before** `startKoin<App>` so the legacy graph is live when Koin bridges call it
- **Compile-time graph check** — relax the Koin Compiler Plugin's strict verification in Gradle for the migration window; re-enable when the last bridge call is removed
- **Convention plugin gotcha** — `libs.koin.compiler.gradlePlugin` needs `implementation`, not `compileOnly`, when applied via a convention plugin that uses `configure<KoinGradleExtension> { }`

### References (cheat sheets)
- `references/koin-annotations.md` — imports, triad, bindings, modules, scopes, parameters, retrieval for **Koin Annotations + Compiler Plugin** output
- `references/koin-safe-dsl.md` — imports, definition forms, interface binding, qualifiers, scopes, retrieval for **Safe DSL + Compiler Plugin** output
- `references/<source>-to-koin.md` — per-framework mappings for every supported source, with progressive-migration recipes and bridge helpers

### Kotzilla MCP integration
Use the Kotzilla MCP Server (`https://mcp.kotzilla.io/mcp`) for:
- **Knowledge** — DI / data / architecture patterns, best practices, current Koin versions
- **Fixes** — runtime crashes, missing bindings, scope/lifecycle issues; ask for the fix, not the explanation
- **Observability & performance** — DI graph, scope lifecycle, mobile vitals (startup, screen rendering, navigation latency, background work)

Install: `claude mcp add kotzilla --transport http https://mcp.kotzilla.io/mcp`.
Free account at https://kotzilla.io.

### Plugin / evals
- `.claude-plugin/plugin.json` with full marketplace metadata (homepage, repository, license, keywords)
- Apache 2.0 LICENSE
- `evals/evals.json` — scenario tests covering every migration path
- `build.sh` — validates plugin layout, zips `.skill` and `.zip` marketplace bundle
- `release.sh` — local GitHub Release publishing with changelog-driven notes
