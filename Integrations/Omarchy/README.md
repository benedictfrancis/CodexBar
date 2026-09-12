# CodexBar for Omarchy

Native Quickshell bar widget for Omarchy's plugin-based shell. Uses the official
Linux CLI, the current Omarchy theme, and its standard keyboard-aware popup.
No separate daemon or network listener. This does not support older Waybar-based
Omarchy installations.

Install a Linux `codexbar` release (keep its resource bundle alongside the binary),
then run from the repository root:

```sh
python3 Integrations/Omarchy/install.py --executable /absolute/path/to/codexbar
```

The installer backs up `shell.json`, copies the plugin into the user plugin
directory, and adds it to the right side of the bar. The shell hot-reloads it and
loads it again at login. Existing layout entries are preserved.

The default provider is Codex. Authenticate with the provider's CLI first. Use
`--provider both` for Codex and Claude or another CodexBar provider ID. Provider
support and authentication are the same as the installed Linux CLI; this is a
usage frontend, not a port of macOS account management or browser imports.

Click the bar label for usage windows, credits and reset countdowns. Percentages
show **remaining** quota. Middle/right-click or press **R** in the popup to
refresh; **Escape** closes it. Polling defaults to five minutes, never overlaps,
and has a 60-second deadline. Failed refreshes keep the last response with a
stale warning. Provider failures remain separate from successful providers.
The widget does not display account identities or raw provider errors.

The `steipete.codexbar` entry in `~/.config/omarchy/shell.json` accepts `executable`,
`provider`, and `refreshSeconds` (minimum 60). To remove the widget, remove its
layout entry and user plugin directory, or use `omarchy plugin remove`.

The popup's Settings section persists provider, source, account number, all-account
display, identity visibility, and polling interval in the same layout entry. Use
`enabled` to follow providers enabled in the CodexBar config. Account selectors
apply only to single-provider queries and select the displayed account; they do
not change the provider CLI's active login. Identity is hidden by default. The bar
shows at most two account/provider summaries, with an overflow count; the popup
shows all results. Changing provider/source discards the previous selection's
data, including a response that completes after the selection changed.

Provider cards also display service status, pace summaries, and the CLI's generic
detail sections with bar/line charts. Email values in detail rows are redacted
unless identity display is enabled. Hover charts to inspect recorded values.
Unknown data stays unavailable; absent daily history is not filled into charts.

The separate Local Spending section scans Codex and Claude session history when
the popup opens, caches it for five minutes, and refreshes alongside manual usage
refreshes. It shows calendar-day cost, 30-day cost, token mix, provenance, history
coverage, and recorded daily costs. This is machine-local history across accounts,
not the selected quota account's bill. Cost fetching cannot delay usage results.
Both spending and service-status fetching can be disabled in Settings.

Optional desktop notifications use Omarchy's existing notification daemon via
`notify-send`. Enable them and choose a remaining-quota threshold in Settings.
They fire on threshold crossings, observed reset-window changes with replenished
quota, and service-status transitions. Startup, unchanged results, unknown data,
and provider errors stay silent. Only one bar instance emits notifications. To
avoid attributing an alert to the wrong account, notifications skip providers
with multiple account rows; select one account for alerts. State is in memory and
restarts quietly after shell reload. No account identities appear in notifications.

Copy usage summary sends a plain-text, identity-free summary to the Wayland
clipboard through `wl-copy`. Neither action needs another daemon or network port.

Validation:

```sh
node --test Integrations/Omarchy/test.mjs Integrations/Omarchy/notifications.test.mjs
python3 Integrations/Omarchy/test_install.py
omarchy plugin validate Integrations/Omarchy
```
