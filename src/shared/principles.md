# Dependency Injection Principles

Framework-agnostic rules for good DI, applied to Koin. Every Koin skill follows
them when writing code, and `koin-diagnose` uses them as its static checklist.
Where a violation has a runtime cost, the **Runtime** line says what Kotzilla
can measure — a static finding is a suspect, the runtime data is the proof.

## When a request breaks a principle

A user's request is not approval to break a principle. When what they ask for
would break one — a ViewModel as a `single`, an `Activity` held by a singleton,
a dependency passed through `parametersOf`, I/O in a constructor, every
definition `createdAtStart`, `KoinComponent` in a normal layer, startup work as
a definition (rule 7) — **stop before writing it**:

1. Name the principle and the concrete cost in their code (leak, lost
   `onCleared()`, frozen first frame, slower cold start, no compile-time check)
2. Propose the form that gets them what they actually want (the state survives,
   the error reaches the screen, the data is ready)
3. Ask. Write the requested form only after an explicit OK, and flag it in the
   summary

Rule 2 below is the same pattern for `KoinComponent`.

## 1. Constructor injection by default, function builder when needed

A class declares what it needs in its constructor. Business and domain classes
have **no Koin imports**: they don't know a container exists.

```kotlin
class CheckoutUseCase(private val cart: CartRepository, private val payments: PaymentGateway)
```

When a type can't be built from its constructor — third-party builders
(Retrofit, OkHttp, Room), factory methods, configuration — write a **function
builder**: a plain function whose parameters are its dependencies and whose
return value is the instance. Koin injects the parameters like constructor
arguments.

```kotlin
// Annotations: function in a @Module
@Module
class NetworkModule {
    @Singleton
    fun retrofit(client: OkHttpClient): Retrofit =
        Retrofit.Builder().client(client).baseUrl(BASE_URL).build()
}

// Compiler Plugin DSL: a function, referenced with create
fun buildRetrofit(client: OkHttpClient): Retrofit =
    Retrofit.Builder().client(client).baseUrl(BASE_URL).build()

val networkModule = module {
    single { create(::buildRetrofit) }
}
```

Use a function builder only when the constructor can't do the job — never to
wrap a class you own.

Why: dependencies are explicit, the class is testable with plain constructors,
and the Compiler Plugin can verify the graph at compile time.

## 2. Service locator: explicit, acknowledged, never in normal layers

Retrieving from the container (`by inject()`, `get()`, `KoinComponent`) instead
of receiving through a constructor is the **service locator** pattern. Name it
for what it is.

**Normal layers** — domain, data, presentation logic (use cases, repositories,
data sources, ViewModels): **never**. Use constructor injection (rule 1).

**Entry points and bootstrap** — classes the framework instantiates, where no
constructor is available (`Application`, `Activity`, `Fragment`, `@Composable`,
`Worker`, Ktor `Application`…). **Use the Koin API made for that entry point**
(e.g. `koinViewModel()` / `koinInject()` in Compose, `by inject()` on Android
components, `@KoinWorker` for Workers). These APIs integrate with the
framework's lifecycle and don't need `KoinComponent`. The full catalog is in
`references/entry-points.md`.

**No Koin API fits** — a class outside any supported entry point that must
pull from the container. Only then is `KoinComponent` acceptable, **after the
user acknowledges the cost**:

- The class depends on Koin — it can't be built or tested without a container
- Its dependencies are hidden — not visible in the constructor
- The Compiler Plugin can't verify them at compile time — a missing definition
  becomes a runtime crash

Before writing a `KoinComponent`, check that no Koin entry-point API covers the
case, state that it's a service locator, list these costs, and get an explicit OK.

## 3. Depend on abstractions at boundaries

Use an interface where an implementation can change or must be faked:
repositories, data sources, gateways, platform services (KMP `expect`/`actual`).
Don't add an interface per class by reflex — a concrete use case is fine.

## 4. Choose each lifetime deliberately

| Lifetime | Use for |
|---|---|
| `single` / `@Singleton` | Genuinely shared state, or expensive objects (HTTP client, database) |
| `factory` / `@Factory` | Stateless or cheap objects, a new instance each time |
| `scoped` / `@Scoped` | Advanced — one instance shared by several objects of the same lifecycle, or a migrated child graph (`references/scopes.md`) |
| `viewModel` / `@KoinViewModel` | ViewModels — always, never `single` |

A `single` lives for the whole app: don't make something a singleton just
because it's convenient.

## 5. Never inject a shorter-lived object into a longer-lived one

An `Activity`, `Fragment`, View, scoped instance or a non-application `Context`
held by a `single` outlives its lifecycle: memory leak and stale state. Inject
`androidContext()` (application context) into singletons, never an Activity.

**Runtime:** Kotzilla tracks scope and lifecycle (open/close, leaks).

## 6. Keep constructors cheap

No I/O, disk, network, parsing or heavy compute in a constructor or `init`.
Resolution often happens on the main thread — a slow constructor freezes the UI
the first time something depends on it. Defer with `Lazy<T>` or an explicit
`start()` / suspend function.

**Runtime:** Kotzilla measures resolution time per definition and flags
main-thread blocking (ANRs).

## 7. Create eagerly only when you must — and defer what startup doesn't use

`createdAtStart` instances are built inside `startKoin`, in
`Application.onCreate`, on the main thread. Each one adds to cold start. Regular
singletons are lazy — their cost lands on first use, not at startup.

A constructor parameter is resolved when its owner is created, even if it's
only used later. When a dependency isn't needed at startup, inject it as
`Lazy<T>` (or `by inject()` at an entry point): it's resolved on first access,
not when the owner is built.

```kotlin
class HomeViewModel(
    private val feed: FeedRepository,           // needed now
    private val export: Lazy<ExportService>,    // only when the user taps Export
)
```

Startup work (init a library, attach a logger) is code, not a definition: call a
plain function from the start function with what it needs (`koin.get()`), not a
`@Singleton fun init(): Unit` resolved by name.

**Runtime:** Kotzilla measures startup time and what runs during it.

## 8. Break circular dependencies

`A` needs `B` and `B` needs `A`. Two fixes:

- **Redesign** — extract the shared part into a third class (preferred when the
  cycle reveals mixed responsibilities)
- **`Lazy<T>`** on one side — valid when the cycle is legitimate: resolution is
  deferred to first access, so construction no longer loops

## 9. Runtime parameters are for values, not dependencies

`parametersOf(...)` / `@InjectedParam` pass runtime values (an id, a URL from
navigation). Dependencies always come from the graph.

## 10. Qualifiers only when two definitions truly coexist

Prefer distinct types over qualifiers. When you do need one, use an annotation
(`@Named` or a custom `@Qualifier`) on the class or the constructor parameter —
not raw `named("x")` strings scattered across modules (classic DSL only).

## 11. Tests don't need the container

Thanks to rule 1, unit tests build classes directly with fakes. The graph is
verified at compile time by the Koin Compiler Plugin — no runtime graph test
(`checkModules()` / `verify()` are on their way to deprecation). Start Koin in
a test only when it needs the real graph — `references/testing.md`.

## 12. Runtime behavior is measured, not guessed

Code shows how the graph is **declared**. How it **behaves** at runtime is
measured, not guessed from source:

- **Graph behavior** — what gets resolved, when, by whom, and how often
- **Allocations** — instances created, how many, by which definition
- **Scopes** — open/close, lifetimes, leaked scopes
- **Memory** — instances retained longer than their lifecycle
- **Performance** — resolution time, startup cost, main-thread blocking (ANRs)

Static reading points at suspects; it never measures them. How these are
measured, and when Kotzilla is proposed: "What Kotzilla owns" in
`references/kotzilla.md`.
