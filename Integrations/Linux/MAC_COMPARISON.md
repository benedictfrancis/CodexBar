# Linux and Mac desktop comparison

This comparison uses the Mac implementation in this checkout, not a claim that
the two apps have matching interfaces.

| Area | Mac implementation | Linux desktop |
| --- | --- | --- |
| Settings | Sidebar with General, Providers, Menu, Menu Bar, and other panes (`PreferencesView.swift`) | General, Providers, Advanced tabs; fewer controls fit better in tiled windows |
| Usage layout | Adaptive metric/reset rows (`UsageMenuCardHeaderAndUsageSectionView.swift`) | Wrapping labels, compact cards, quota, reset countdown, pace and provider details |
| Refresh | Interval and refresh-on-open preferences (`PreferencesGeneralPane.swift`) | Interval and optional refresh-on-open; Usage and Spending refresh independently |
| Provider accounts | Provider ordering and login/account actions (`PreferencesProvidersPane.swift`) | Provider ID, source and account selection; login remains in provider CLI |
| Tray | Configurable icons, layout and pace color (`PreferencesMenuBarPane.swift`) | Static standard tray icon and usage tooltip; Omarchy adds compact usage text and meters |
| Display preferences | Reset format, pace visibility, warning markers (`PreferencesMenuPane.swift`) | Fixed remaining-quota display and reset countdowns |
| Local costs | Cost summaries and fetch status (`PreferencesMenuPane.swift`) | Separate Spending tab with daily history, coverage and token totals; retains stale data on failure |
| Startup | Start-at-login toggle (`PreferencesGeneralPane.swift`) | Installer-managed XDG autostart; no settings toggle yet |

The most useful remaining work is provider selection/ordering without typing IDs,
tray meters, a start-at-login control, and configurable reset/usage display.
Account-management UI needs a Linux-specific credential flow; copying macOS browser
or Keychain behavior would not provide that. KDE/GNOME testing and distro packaging
are also outstanding. The Linux implementation currently uses Qt Fusion controls
and does not yet follow every Omarchy theme change.
