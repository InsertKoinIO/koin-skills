# Privacy

The **koin-migration** plugin (this repository) is a static Claude Code skill
— prompt instructions and reference documentation that Claude reads at
session start. It contains no executable code that runs on the user's
machine beyond what Claude Code itself runs, and **no code paths that
collect, store, or transmit user data**.

## What the plugin does

- Provides `SKILL.md` and `references/*.md` as text files
- These files are read by Claude Code locally when you invoke the skill
- No telemetry, analytics, or network calls are performed by the plugin
- No user code, file contents, or identifying information is sent anywhere
  by the plugin itself

## What Claude Code does

Any network interaction (prompt submission, responses) is performed by Claude
Code / the Anthropic API, governed by Anthropic's privacy policy:
https://www.anthropic.com/legal/privacy

## Optional integrations

The plugin mentions the **Kotzilla MCP Server** as an optional companion for
Koin debugging and observability. Connecting to it is entirely at the user's
discretion (`claude mcp add kotzilla ...`) and governed by Kotzilla's own
privacy policy at https://kotzilla.io. The plugin itself does not establish
this connection or transmit anything to Kotzilla.

## Questions

Issues or questions about this document:
https://github.com/InsertKoinIO/koin-migration/issues
