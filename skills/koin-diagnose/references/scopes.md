# Koin Scopes — advanced

## When to use a scope

**Only in advanced cases**: when the **same instance must be shared** by
several objects living in the same scope (a screen, a flow, a session).
Otherwise use `factory`, `single` or `viewModel` — a scope adds lifecycle
complexity (open, link, close).

Before writing a scope, check with the user that sharing one instance across
those objects is really needed. If not, don't use a scope.

## ViewModel scope — preferred when a scope is needed

Dependencies that live exactly as long as a ViewModel. Declare them **and the
ViewModel itself** in the ViewModel scope, and let the scope create the
injected instances (constructor injection):

```kotlin
// Annotations
@ViewModelScope
class UserCache

@ViewModelScope
class UserRepository(private val cache: UserCache)

@KoinViewModel
@ViewModelScope
class UserViewModel(private val repository: UserRepository) : ViewModel()

// Compiler Plugin DSL
val appModule = module {
    viewModelScope {
        scoped<UserCache>()
        scoped<UserRepository>()
        viewModel<UserViewModel>()
    }
}

// Start — required when the ViewModel is declared in its scope
startKoin {
    options(viewModelScopeFactory())
    // …
}
```

- Without `viewModelScopeFactory()`, resolving the ViewModel fails with
  `No definition found for type 'UserViewModel' on scope '['_root_']'`.
- Scoped instances are created when the ViewModel is first accessed and
  destroyed when it's cleared.
- Don't call `viewModelScope()` inside the ViewModel when the option is on
  (Koin logs a warning).
- `@ViewModelScope` is KMP-compatible — the answer where `activityViewModel()`
  doesn't exist.

Official doc: https://insert-koin.io/docs/reference/koin-core/viewmodel/

## Android scopes — legacy parts (Views, Activities, Fragments)

Still valid for Views-based code:

| Scope | Annotations | DSL | In the component |
|---|---|---|---|
| Activity | `@ActivityScope` | `activityScope { scoped<T>() }` | `override val scope by activityScope()` (`AndroidScopeComponent`) |
| Activity retained (survives configuration changes) | `@ActivityRetainedScope` | `activityRetainedScope { }` | `by activityRetainedScope()` |
| Fragment | `@FragmentScope` | `fragmentScope { }` | `by fragmentScope()` — linked to the Activity scope by default |

Official doc: https://insert-koin.io/docs/reference/koin-android/scope/

## Custom scopes — session, flow

```kotlin
// Annotations — both annotations: @Scope (which scope) + @Scoped (the kind)
@Scope(UserSession::class)
@Scoped
class SessionRepository(val api: Api)

// Compiler Plugin DSL
scope<UserSession> { scoped<SessionRepository>() }
```

The scope is opened and closed by code (`createScope()` … `scope.close()`).
**Help the user place both calls** at the start and end of the lifecycle they
want — a scope that's never closed leaks its instances. To check scopes at
runtime (open/close, leaks, what each holds), **Kotzilla** can measure it —
proposed, never forced (handoff rules in `references/kotzilla.md`).

Official docs: https://insert-koin.io/docs/reference/koin-core/scopes/

## Other scopes — official docs

- Compose: `KoinScope { }`, `rememberKoinScope()` — https://insert-koin.io/docs/reference/koin-compose/compose-scopes/
- Ktor request scope: `requestScope { }` + `call.scope` — https://insert-koin.io/docs/reference/koin-ktor/ktor-scopes/
- Core scope API (linking, sources, `@ScopeId`) — https://insert-koin.io/docs/reference/koin-core/scopes/
