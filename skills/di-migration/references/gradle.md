# Koin Gradle Setup

The one Gradle reference for every Koin skill. Versions: `references/rules.md`
§3 (defaults + latest check on Maven Central). KSP: never (`rules.md` §2).

```kotlin
// build.gradle.kts
plugins {
    id("io.insert-koin.compiler.plugin") version "$koinCompilerVersion"
}

dependencies {
    implementation(platform("io.insert-koin:koin-bom:$koinVersion"))   // versions of every Koin artifact below
    implementation("io.insert-koin:koin-core")
}
```

**Add only the artifacts the project needs:**

| Need | Artifact | KMP source set |
|---|---|---|
| Always | `koin-core` (+ `koin-bom`) | `commonMain` |
| Annotations style | `koin-annotations` | `commonMain` |
| Android | `koin-android` | `androidMain` |
| Compose | `koin-compose` | `commonMain` |
| ViewModel in Compose & KMP | `koin-compose-viewmodel` | `commonMain` |
| Navigation 3 (recommended) | `koin-compose-navigation3` | `commonMain` |
| Navigation 2: graph-shared ViewModels | `koin-compose-viewmodel-navigation` | `commonMain` |
| WorkManager | `koin-androidx-workmanager` | `androidMain` |
| Start via AndroidX App Startup | `koin-androidx-startup` | `androidMain` |
| Ktor server | `koin-ktor` | server / JVM |
| Ktor logging | `koin-logger-slf4j` | server / JVM |
| Tests | `koin-test` + `koin-test-junit4` or `koin-test-junit5` | `commonTest` / `test` |
| Migration from / coexistence with Hilt | `koin-dagger-bridge` | `androidMain` |

- **`koin-annotations`** — required for the Annotations style. With Compiler Plugin DSL,
  needed only when classes carry Koin annotations (`@InjectedParam`, `@Named`,
  `@Qualifier`…). The Compiler Plugin DSL functions themselves are in `koin-core`.
- **`koin-dagger-bridge`** — Hilt only: lets Koin definitions read Hilt
  bindings (`dagger<T>()` on a Hilt `@EntryPoint` interface `T`, through Hilt's
  `EntryPoints`). Plain Dagger 2 needs no artifact. Both:
  `references/bridging.md`.
- **KMP** — one plugin, no per-target configuration.
- **Compiler Plugin options** (optional, defaults are fine):

  ```kotlin
  koinCompiler {
      compileSafety = true       // compile-time graph check (default: true) — keep it on
      skipDefaultValues = true   // don't inject parameters that have a default value (default: true)
      userLogs = true            // log detected components in the build output (default: false)
  }
  ```
- **Kotlin** — `2.3.20` or later (`rules.md` §3).
- **Convention plugins** — when the Compiler Plugin is applied through a Gradle
  convention plugin that uses `configure<KoinGradleExtension> { … }`, the
  convention plugin's dependency on the Koin Gradle plugin must be
  `implementation`, not `compileOnly` (otherwise `NoClassDefFoundError:
  org/koin/compiler/plugin/KoinGradleExtension` at configuration time). Working
  example: https://github.com/InsertKoinIO/nowinandroid/blob/koin_plugin/build-logic/convention/src/main/kotlin/KoinConventionPlugin.kt
