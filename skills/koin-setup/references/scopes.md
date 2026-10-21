# Koin Scopes — advanced

## When to use a scope

**Only in advanced cases** — a scope adds lifecycle complexity (open, link,
close).

- **New code** — only when the **same instance must be shared** by several
  objects living in the same scope (a screen, a flow, a session). Check with
  the user first; otherwise `factory`, `single` or `viewModel`.
- **Migration** — the source already models a child graph with its own
  lifetime (Dagger subcomponent, Toothpick child scope, Metro
  `@GraphExtension`) → a scope. State it in the plan, no question. Not a
  `factory` + `@InjectedParam`: nothing would close the group, and Kotzilla
  would see unrelated instances instead of a scope.

## Choose the scope

In this order — stop at the first that fits:

1. **No scope** — `factory`, `single` or `viewModel`.
2. **A scope archetype** when the lifetime matches one: ViewModel
   (`@ViewModelScope` / `viewModelScope { }` — preferred, KMP), Activity,
   retained Activity, Fragment (below). Koin opens and closes it with the
   component: nothing to manage by hand.
3. **A custom scope** only when no archetype fits — a session, a flow, a
   runtime value. The code opens and closes it ("Custom scopes" below).

Migrating: a source scope that follows an Activity, a Fragment or a ViewModel
(a Dagger subcomponent per Activity, a Toothpick scope per screen, a Metro
`@GraphExtension` per screen, a Hilt `ActivityComponent`) maps to the archetype; any other child graph to a custom
scope.

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

## Android scope archetypes — Activity, Fragment

For Views-based code (Compose → the ViewModel scope):

| Scope | Annotations | DSL | In the component |
|---|---|---|---|
| Activity | `@ActivityScope` | `activityScope { scoped<T>() }` | `override val scope by activityScope()` (`AndroidScopeComponent`) |
| Activity retained (survives configuration changes) | `@ActivityRetainedScope` | `activityRetainedScope { }` | `by activityRetainedScope()` |
| Fragment | `@FragmentScope` | `fragmentScope { }` | `by fragmentScope()` — linked to the Activity scope by default |

Official doc: https://insert-koin.io/docs/reference/koin-android/scope/

## Custom scopes — session, flow (no archetype fits)

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

### Scope with a runtime value

A value known only when the scope opens (a user id, a tenant). Declare it into
the scope right after creating it; consumers take it as a `@Provided`
parameter:

```kotlin
class SessionScope                                          // custom scope type

@Scope(SessionScope::class) @Scoped
class SessionRepository(@Provided @UserId private val userId: String, private val api: Api)

// One owner opens and closes it — a @Singleton, injected with the root Scope
@Singleton
class SessionManager(private val rootScope: Scope) {        // org.koin.core.scope.Scope
    private var current: Scope? = null

    fun open(userId: String): SessionRepository {
        current?.close()                                    // replacing → close the previous one
        val scope = rootScope.getKoin().createScope<SessionScope>("session-$userId")
        scope.declare(userId, qualifier<UserId>())          // org.koin.core.qualifier.qualifier
        current = scope
        return scope.get()
    }

    fun close() {                                           // logout
        current?.close()
        current = null
    }
}
```

- **One owner** opens, replaces and closes the scope — the registry is global,
  dropping the reference doesn't free it.
- **Scope ids** — prefixed (`"session-$userId"`), never a bare value.
- **Same value twice** — `createScope` throws `ScopeAlreadyCreatedException`;
  `getOrCreateScope<T>(id)` reuses. Choose explicitly.
- A missing `declare` fails at runtime: cover the owner with a test
  (`references/testing.md`).

Official docs: https://insert-koin.io/docs/reference/koin-core/scopes/

## Other scopes — official docs

- Compose: `KoinScope { }`, `rememberKoinScope()` — https://insert-koin.io/docs/reference/koin-compose/compose-scopes/
- Ktor request scope: `requestScope { }` + `call.scope` — https://insert-koin.io/docs/reference/koin-ktor/ktor-scopes/
- Core scope API (linking, sources, `@ScopeId`) — https://insert-koin.io/docs/reference/koin-core/scopes/
