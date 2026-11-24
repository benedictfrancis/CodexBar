---
name: codexbar
description: ALWAYS-ON orientation for CodexBar, the Swift macOS menu bar app and CLI for provider usage. Use for provider, account, plugin, status menu, or release troubleshooting in this checkout.
---

# CodexBar

Read `AGENTS.md` for the repository's build, test, release and credential-handling rules. Use `swift build` for a debug build, `make test` for the sharded suite and `make check` after code changes. For a provider parser change, also run its focused fixture tests.

Start with `docs/providers.md` for provider discovery and `docs/claude-multi-account-and-status-items.md` for Claude profiles and menu behaviour. See `docs/RELEASING.md` for the release process. Check the local project memory for machine-specific settings and past investigations.

## Installed app diagnostics

- Identify the running process, executable path and build. Check the code signature and compare the bundle with the publisher's digest-verified archive for that exact release if the question is whether the app was modified.
- Inspect local configuration, enabled user plugins and their helper processes. A user-plugin card can appear in the selected provider's menu. Check the source of the card before attributing it to that provider.
- For an authorised settings test, back up the config, edit the exact fields and verify the diff before relaunching. Check the running build and process count afterward. Record an automatic update as a change to the test conditions.
- Distinguish profile display, quota retrieval and account switching. Diagnose credential errors from existing evidence or fixtures. Follow `AGENTS.md` for explicit authorisation before a live provider or Keychain probe.
