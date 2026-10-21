# Privacy

The **koin** plugin (this repository) is a static Claude Code skill
— prompt instructions and reference documentation that Claude reads at
session start. It contains no executable code that runs on the user's
machine beyond what Claude Code itself runs, and **no code paths that
collect, store, or transmit user data**.

## What the plugin does

- Provides `SKILL.md` and `references/*.md` as text files
- These files are read by Claude Code locally when you invoke the skill
- No telemetry or analytics; the only network endpoint the plugin declares is
  the Kotzilla MCP Server (below)
- No user code, file contents, or identifying information is sent anywhere
  by the plugin itself

## What Claude Code does

Any network interaction (prompt submission, responses) is performed by Claude
Code / the Anthropic API, governed by Anthropic's privacy policy:
https://www.anthropic.com/legal/privacy

## Kotzilla MCP Server

The plugin declares the **Kotzilla MCP Server** (`https://mcp.kotzilla.io/mcp`)
as an optional companion for Koin debugging and observability. Claude Code
lists it as needing authentication and may contact the endpoint to check its
status; no code, file contents or prompts are sent to it.

Using it requires the user to sign in explicitly (OAuth, through `/mcp`) with a
Kotzilla account. Only after that can Claude call its tools, and what those
calls send is governed by Kotzilla's own privacy policy at https://kotzilla.io.
Users who don't sign in, or disable the server in `/mcp`, never use it.

## Questions

Issues or questions about this document:
https://github.com/InsertKoinIO/koin-skills/issues
