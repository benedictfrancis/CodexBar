# CodexBar for Linux

A Qt 6 desktop app with separate Usage & Spend and Settings windows, an optional
system tray icon, and a launcher entry. The Swift `codexbar` CLI owns provider
fetching and authentication. The desktop owns polling, settings, notifications,
and a private local socket for desktop adapters. No HTTP server is needed.

## Build and install

Requires Linux, C++17, make, qmake6, and Qt 6.4 or newer: Base, Declarative/Quick,
Quick Controls, Network, D-Bus, and SVG icon support. Install Qt's Wayland plugin
for Wayland sessions. On Arch/Omarchy these are `base-devel qt6-base
qt6-declarative qt6-svg qt6-wayland`.

Install a CodexBar Linux CLI release, keeping its resource bundle beside the
executable, and authenticate with the provider's CLI. From the repository root:

```sh
mkdir -p .local/linux-build
cd .local/linux-build
qmake6 ../../Integrations/Linux/codexbar-linux.pro
make -j4
cd ../..
python3 Integrations/Linux/install.py --cli /absolute/path/to/codexbar
~/.local/bin/codexbar-linux --settings
```

Add `--omarchy` to install the compact Omarchy adapter. Add `--no-autostart` to
disable starting at login. Installation is per user, preserves settings, and
backs up existing preferences before changes. Reinstallation preserves disabled
autostart. This source build is not yet a distro package or self-contained binary.

Qt supports Wayland and X11. The tray uses Qt's desktop integration (StatusNotifier
or X11 tray host). GNOME may require a tray extension; the launcher and windows
work without a tray. Omarchy installation hides the duplicate tray by default.
KDE, GNOME, and other compositor sessions still need hands-on compatibility testing.

## Windows and behavior

Settings is divided into General, Providers, and Advanced. It controls
provider/source selection, account index, all-account display,
identity visibility, refresh interval, status, local spending, notifications, and
tray visibility. Account selectors choose displayed usage; they do not change the
provider CLI's login. Provider support follows the installed CLI. Browser imports
and macOS account management are not implemented here.

Usage displays remaining quota, reset times, pace, credits, status, generic provider
details, and charts. Unknown values stay unknown. Identity is hidden by default.
Local Spending shows Codex/Claude history across accounts on this machine, with
calendar-day and 30-day estimates, token mix, provenance, and coverage. Estimates
are not invoices. Opening spending scans independently of quota polling, with a
five-minute cache; Refresh forces a new scan.

Quota polling defaults to five minutes. Optional refresh-on-open updates usage
when its window opens. Refresh and Ctrl+R update the selected tab independently;
Ctrl+, opens Settings, and Ctrl+Q quits. Queries never overlap within each stream,
stop after 60 seconds, and cap output at 8 MiB. Failed refreshes retain previous
results with a stale indicator. Changing selection rejects old in-flight results.
Optional notifications use the desktop's D-Bus notification service for remaining
quota threshold crossings, observed resets, and service-status transitions.
Startup, provider errors, and ambiguous multi-account results stay silent.

Closing a window leaves the backend running. Quit from the usage window or tray,
or use `codexbar-linux --quit`. Launching again opens the existing process.
Preferences live in `$XDG_CONFIG_HOME/codexbar/linux.json` (normally `~/.config`),
written atomically with user-only permissions. Invalid files are never overwritten:
fix or remove the file and restart. Authentication remains in the CLI's stores.

## Adapter interface

```sh
codexbar-linux --background
codexbar-linux --usage
codexbar-linux --settings
codexbar-linux --spending
codexbar-linux --refresh
codexbar-linux --snapshot
codexbar-linux --configure '{"provider":"both","refreshSeconds":300}'
codexbar-linux --quit
```

Snapshot, refresh, configure, and quit require an existing process. UI commands
start one when needed. IPC clients load no GUI plugin. `--cli PATH` and `--no-tray`
apply when starting a new instance. The private, same-user local socket lives at
`$XDG_RUNTIME_DIR/codexbar-linux/desktop.sock`; requests and replies are newline
terminated JSON. Snapshot schema version 1 includes compact provider windows,
summary, update time, busy/stale/error state, and spending availability. It excludes
account identity and configuration. Adapters should check `schemaVersion`, tolerate
unknown fields, and treat a missing backend as unavailable.

## Validation and removal

```sh
node --test Integrations/Omarchy/test.mjs Integrations/Omarchy/notifications.test.mjs
python3 Integrations/Omarchy/test_install.py
python3 Integrations/Linux/tests/test_desktop.py
```

Runtime tests isolate HOME/XDG paths and use a fake CLI and offscreen Qt. Set
`CODEXBAR_TEST_PLATFORM=xcb` to exercise X11 on a session with DISPLAY access.

To uninstall, quit CodexBar and remove `~/.local/bin/codexbar-linux`,
`$XDG_DATA_HOME/applications/com.steipete.CodexBar.desktop`,
`$XDG_DATA_HOME/icons/hicolor/scalable/apps/codexbar.svg`, and
`$XDG_CONFIG_HOME/autostart/com.steipete.CodexBar.desktop`.
The default data/config directories are `~/.local/share` and `~/.config`.
Preferences and their backups can be retained for a later reinstall.
