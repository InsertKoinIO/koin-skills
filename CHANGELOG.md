# Changelog

All notable changes to the **koin-migration** plugin are documented in this file.
This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

Work in progress toward 2.0.0 (plugin rename `koin-migration` → `koin`).

### Changed
- Eval cases and the eval harness moved to a separate repo: skills no longer ship an `evals/` folder

### Added
- `koin-setup` skill — set up Koin in a new or legacy project, or alongside an existing DI container
- `koin` skill — write Koin code following the project's style and the Koin rules
- `koin-diagnose` skill — Koin errors (Kotzilla MCP `koin_diagnose`, no SDK needed) and app behavior (static suspects, then proof with the Kotzilla MCP + SDK)
- `shared/` references used by every skill: rules, DI principles, Gradle, entry points, scopes, Kotzilla handoff

### Changed
- Build: sources hold no copies — `build.sh` assembles self-contained skills in `build/` (git-ignored), with a source-duplication check and a post-build completeness check
- `di-migration` reads the shared references instead of owning duplicated rules; Kotzilla handoff is a step of the per-module validation loop
- Default versions Koin 4.2.2 / Compiler Plugin 1.2.1, latest checked on Maven Central
- Graph verification is compile-time (Compiler Plugin); `checkModules()` / `verify()` no longer emitted
- Compose: `koin-compose` + `koin-compose-viewmodel`; `KoinContext` removed (deprecated)

### Fixed
- Hilt / Dagger bridge artifact is `koin-dagger-bridge` (`koin-android-dagger` doesn't exist)
- Android scopes use `AndroidScopeComponent`
- Safe DSL without the Compiler Plugin fails at runtime (stubs), not "compiles without checks"

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
