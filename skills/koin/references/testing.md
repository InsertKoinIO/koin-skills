# Testing with Koin

**Graph verification is compile-time** — the Koin Compiler Plugin checks it at
build time. No `checkModules()` / `verify()` test (`rules.md` §6).

## Plain unit tests — no Koin

With constructor injection (`principles.md` rule 1), build the class directly
with fakes. Most unit tests need no container.

## Tests with Koin started — `koin-test`

When the test needs the real graph (or part of it), start Koin for the test and
inject into the test class. `KoinTest` gives the test `by inject()` / `get()`.

```kotlin
// JUnit 4 — koin-test-junit4: the rule starts Koin before each test and stops it after
class CheckoutTest : KoinTest {

    @get:Rule
    val koinTestRule = KoinTestRule.create {
        modules(checkoutModule)                    // Annotations: modules(module<CheckoutModule>())
    }

    private val checkout: CheckoutUseCase by inject()   // injected automatically

    @Test
    fun `checkout uses the cart`() { /* … */ }
}

// JUnit 5 — koin-test-junit5
class CheckoutTest : KoinTest {
    @JvmField
    @RegisterExtension
    val koinTestExtension = KoinTestExtension.create { modules(checkoutModule) }
}
```

- Load **only the modules the test needs**. With Annotations, load them
  explicitly with `module<T>()` (`rules.md` §5 — test overrides are the escape
  hatch case).
- If a test calls `startKoin` itself, it must `stopKoin()` after — the rule and
  the extension do it for you.

## Replace a definition with a fake or a mock

```kotlin
// A definition on the fly, inside the test
declare<PaymentGateway> { FakePaymentGateway() }

// A mock — register the mock provider once, then declare the mock
@get:Rule
val mockProvider = MockProviderRule.create { clazz -> mockkClass(clazz) }   // JUnit 5: MockProviderExtension

declareMock<PaymentGateway> { every { pay(any()) } returns Result.success(Unit) }
```

## Official docs

- Testing: https://insert-koin.io/docs/reference/koin-test/testing/
- Android instrumented tests: https://insert-koin.io/docs/reference/koin-android/instrumented-testing/
- Compose tests and previews: https://insert-koin.io/docs/reference/koin-compose/compose-testing/
