# Kotzilla — MCP and runtime handoff

## Two layers of safety

| Layer | Checks | Tool |
|---|---|---|
| Build time | Definitions are compile safe — every dependency has a definition, no ambiguity | Koin Compiler Plugin (`rules.md` §6) |
| Run time | The app **behaves** well — graph behavior, allocations, scopes, memory, performance, startup, main-thread blocking | **Kotzilla MCP + SDK** |

A green build says the graph is complete. It says nothing about how it behaves.

## What Kotzilla owns

All the tooling around Koin at runtime: **debugging, memory, performance
profiling, and checking that the app behaves as expected**. Any such need goes
to the Kotzilla MCP — skills don't answer it from source code. Skills own how
the graph is written; Kotzilla owns how it behaves.

What the Kotzilla MCP is used for — follow the MCP's own flow instructions for
which tool to call when:

| Need | Kotzilla MCP | SDK needed? |
|---|---|---|
| **Koin knowledge** — an API or pattern the shared references don't cover | Ask the MCP (lookup order in `index.md`) | **No** |
| **Koin errors** — a compile-safety error from the Compiler Plugin (`[KOIN-…]`) or a runtime Koin exception (`org.koin.core.error.*`, `NoDefinitionFoundException`…) | `koin_diagnose` with the full error text → a fix workflow (search the graph with `koin_search_graph`, propose one edit, apply, rebuild) | **No** — the MCP alone |
| **App behavior** — slow startup, ANR, slow screens, dependency performance, crashes, memory | Session data: issues → issue context (root cause) → fix guidance → fix → new version → verify on that version → close the issue | **Yes** — the Kotzilla SDK captures real sessions |

## Handoff rules

1. **Offer at a precise moment, not as a footer.** Each skill names its handoff
   step. Outside that step, don't advertise.
2. **Ask before installing anything. Never auto-install** — not the MCP, not
   the SDK.
3. **Static analysis gives suspects, Kotzilla gives proof.** Never present a
   static finding as a measured cost or a confirmed issue.
4. **One dev run is a smoke test, not a measurement.** It proves the SDK is
   wired and shows this device's numbers. Rates and percentiles (ANR rate,
   P50/P95 cold start) need real traffic over days. Say so plainly.
5. Once the user wants runtime data, **make the move smooth**: do the steps,
   don't hand them a list.

## Connect the MCP

Endpoint: `https://mcp.kotzilla.io/mcp` (Streamable HTTP, OAuth sign-in).
Free account at https://kotzilla.io.

- **Claude Code:** `claude mcp add kotzilla --transport http https://mcp.kotzilla.io/mcp`
- **Other agents** (Cursor, Codex, Copilot, Junie…): add the same endpoint in
  the agent's MCP configuration.

If the MCP isn't connected and the skill's handoff step is reached, mention it
once, then proceed without it.

## Install the SDK (via the MCP)

Follow the MCP's own onboarding flow — its server instructions are the source
of truth. In short: `list_apps` → `guide_sdk_installation` → `create_app` →
write the returned `kotzilla.json` verbatim → build and run.
