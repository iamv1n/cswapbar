# Changelog

All notable changes to CSwapBar are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before 1.0, minor versions (0.x.0) may include breaking changes to settings or behavior.

## [Unreleased]

### Added

- **Notifications** for usage crossing 80%, 95%, or 100% (each level can be turned off; limit alerts include the reset time), for account switches made outside CSwapBar (such as CSwap's auto-switch), for failed switches, and for accounts that need a new login. Nothing is sent for what's already true at launch, and every message follows the privacy settings. Turning on Privacy Mode clears delivered notifications. Settings → Notifications has a test button and links to System Settings when notifications are blocked.
- **Global Privacy Mode shortcut**, ⌃⌥⌘P by default, that works from any app with no Accessibility permission. Record your own in Settings → Privacy.
- **Custom themes** in Settings → Appearance, next to the built-in ones: themes built from five colors (solid or gradient), with contrast warnings, duplicate, delete, and import/export as JSON; plus shape options for every theme: corners (Boxy, Soft, Rounded, Round), borders, bar and ring thickness, and pill or square buttons.
- **Keyboard control.** ⌃⌥⌘C opens or closes the popover from any app (recordable). In the popover, ↑/↓ highlight an account (across pages), Return switches to it, and ⌘1–⌘9 switch directly. In Settings, ⌘1–⌘9 jump between pages. Settings → General lists every shortcut.
- **Open at login** (Settings → General → Startup), using macOS login items; it shows when macOS is waiting for your approval.
- **Configurable usage colors.** Choose where bars and rings turn yellow, orange and red (Settings → Layout → Usage Colors).
- **CSwap executable override.** Pick the `cswap` binary by hand in Settings → General; when set, it's the only path used, so a wrong path is reported instead of silently using another copy.
- **CSwap's own menu bar app is detected** passively (its LaunchAgent file and the running-apps list; no commands are run). Settings explains what running both means and how to remove it.
- **Usage history** (Settings → History): a reading every 5 minutes per account and every account switch, kept in local SQLite for 30 days. Accounts are stored as salted hashes, never emails or names. Export as CSV (names follow the privacy settings at export time; spreadsheet formulas are neutralized), or clear it.
- **Dashboard window** (⌘Y, or History in the popover): Swift Charts of 5-hour or weekly usage per account over 24 hours, 7 days, or 30 days, with your color thresholds, plus a list of switches and where they came from.
- **"Best next account" suggestion** in the popover once the active account passes yellow, using CSwap's `best` rule (most quota left in the tighter window), with one-click Switch.
- **Optional auto-switch** (Settings → Switching, off by default) that runs `cswap auto --json` with your threshold and strategy, shows its latest decision, refreshes as soon as it switches, and stops with CSwapBar (a watchdog stops it even after a crash).
- **Usage Island**, an alternative home for CSwapBar (Settings → General → "Show CSwapBar in", off by default). It replaces the menu bar icon, so only one of the two shows. It's a small black bar at the top-center of the screen with the active account's 5-hour usage, in **Notch** style (hugs the camera notch; floats on screens without one) or **Floating bar**. Hover to expand into both windows, reset times, the suggestion with a Switch button, and your other accounts; click (or ⌃⌥⌘C) to open the popover beneath it. Follows Privacy Mode, shows connection problems, and never takes focus.
- **Resizable Settings window.** The page widens with the window (more theme columns) and never shrinks below the original size; the size is remembered.
- **Update checks** against GitHub Releases (daily, can be turned off) with a popover hint and notification when a new version is out, and optional automatic installs that verify the SHA-256 checksum, bundle ID, version, and signature before replacing the app and relaunching.

## [0.1.0] - 2026-11-23

First public release.

### Added

- **Menu-bar popover** showing every CSwap account with 5-hour and 7-day usage, reset countdowns, plan, and organization. Its height follows its content, with pages of accounts (4 by default) and a page switcher.
- **One-click switching.** Success is reported only after `cswap status` confirms the new account. Concurrent switches are rejected.
- **Privacy Mode** (⇧⌘P) hides emails, names, organizations, and plans across the popover, menu-bar title, widgets, and notification text, using generic "Account 01" labels. Nine individual privacy controls are also available.
- **Four card layouts:** Meters, Classic, Rings, and List.
- **23 themes** in Adaptive, Vivid, Dark, Light, and High Contrast groups, including macOS (system materials), macOS Widgets (Apple system colors), and Glass. Plus 13 accent colors.
- **Typography options:** SF Pro, SF Pro Rounded, New York, or SF Mono, in three text sizes.
- **Desktop widgets:** Gauge, Active Account, and All Accounts. They're draggable, remember their position, and can sit on the desktop or float on top.
- **Settings window** with an ambient-glow design and pages for General, Appearance, Layout, Widgets, Privacy, and About.
- **The Triad logo**, app icon, and brand SVGs.
- **DMG releases** with a drag-to-Applications layout, a first-launch help file, and SHA-256 checksums, plus a full [install guide](docs/INSTALL.md) for unsigned builds.
- **Project website** in `docs/` for GitHub Pages: animated hero, layout switcher, theme marquee, interactive Privacy Mode demo, and install steps.
- **Collaboration files:** CONTRIBUTING, DEVELOPMENT, ROADMAP, SECURITY, CODE_OF_CONDUCT, and issue and PR templates.
- **Developer tooling:** `scripts/setup.sh`, `build.sh`, `test.sh`, `install.sh`, `package.sh` (DMG and zip), `release.sh`, `make-icon.sh`, and `get.sh`. Also UI snapshot flags (`--render-popover`, `--render-settings`, `--render-widget`).
- **Tests:** 74 tests, including WCAG contrast checks for every theme and accent, plus opt-in read-only integration tests against a real CSwap install.

[Unreleased]: https://github.com/iamv1n/cswapbar/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/iamv1n/cswapbar/releases/tag/v0.1.0
