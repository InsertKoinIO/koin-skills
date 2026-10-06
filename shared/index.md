# Shared references — index

Shared by every Koin skill. One owner per topic: when a detail is needed, read
the file that owns it.

| File | Owns |
|---|---|
| `rules.md` | Koin rules: style choice, no KSP, versions, configuration, modules, compile-time verification, service locator, Kotzilla. **Non-negotiable — read first.** |
| `principles.md` | Dependency injection principles — constructor injection, function builders, lifetimes, cheap constructors, Lazy, cycles |
| `gradle.md` | Compiler Plugin, BOM, artifact per need and KMP source set, plugin options |
| `entry-points.md` | Where to start Koin per project type, and the Koin API for every entry point (Android, Compose, ViewModel, Navigation, WorkManager, Ktor, iOS, isolated context) |
| `scopes.md` | Scopes — advanced |
| `koin-annotations.md` / `koin-safe-dsl.md` | Exact syntax and imports — don't infer from memory |
| `kotzilla.md` | Kotzilla MCP and runtime handoff |
