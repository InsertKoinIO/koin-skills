# Privacy

The installed **koin** plugin contains static skill instructions and reference
documentation for Claude Code and Codex. The skills contain no executable code
that collects, stores or transmits user data.

## What the plugin does

- Provides `SKILL.md` and `references/*.md` as text files
- The client reads these files locally when you invoke a skill
- No telemetry or analytics; the only network endpoint the plugin declares is
  the Kotzilla MCP Server (below)
- No user code, file contents, or identifying information is sent anywhere
  by the plugin itself

## What the client does

The client handles model requests, including prompts and responses. Claude
Code's use of the Anthropic API is covered by [Anthropic's privacy policy](https://www.anthropic.com/legal/privacy).
Codex uses the model provider configured for the session.

## Kotzilla MCP Server

The plugin declares the **Kotzilla MCP Server** (`https://mcp.kotzilla.io/mcp`)
as an optional companion for Koin debugging and observability. The client may
contact the endpoint to check its status or discover OAuth settings before you
sign in. These checks do not send project files or prompts to Kotzilla.

Using its tools requires the user to sign in with a Kotzilla account through
`/mcp` in Claude Code or `codex mcp login kotzilla` in Codex. What the tool
calls send is governed by Kotzilla's own privacy policy at https://kotzilla.io.
All four skills can be used without signing in to Kotzilla.

## Questions

Issues or questions about this document:
https://github.com/InsertKoinIO/koin-skills/issues
