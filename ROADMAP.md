# Roadmap

Where CSwapBar is headed. Plans change. Open an [issue](https://github.com/iamv1n/cswapbar/issues) to suggest something or to pick up an item; items marked **help wanted** are good places to start.

## ✅ 0.1: Foundation (released)

- CSwap integration: detection, version check, schema-v1 JSON, read-only integration tests
- Menu-bar popover with paging and content-fitted height
- Verified one-click switching
- Privacy Mode and individual privacy controls
- Four card layouts, 23 themes, accent colors, and typography options
- Desktop widgets (Gauge, Active Account, All Accounts)
- Settings window, logo and app icon, DMG releases

## 🔜 0.2: Daily driver

- [x] **Launch at login** toggle (`SMAppService`)
- [x] **Notifications** for usage thresholds (80% / 95% / 100%), switch results, and accounts that need login. They respect Privacy Mode.
- [x] **Global Privacy Mode shortcut** that works anywhere, not only while the popover is open
- [x] **Keyboard control**: a global shortcut to open the popover, arrow-key navigation, ⌘1–⌘9 switching
- [x] **Custom themes** (make, edit, import/export) and **shape options** (corners, borders, bars, buttons)
- [x] **Update checks** against GitHub Releases, with optional checksum-verified installs
- [x] Resizable Settings window
- [x] **Configurable usage thresholds** (the color bands)
- [x] Detect `cswap menubar` running at the same time and explain what that means
- [x] CSwap executable path override in Settings → General

## 🗓 0.3: History & insight

- [x] **Usage history** in local SQLite: 30-day retention, account IDs hashed, never emails
- [x] **Dashboard window** with Swift Charts: usage over time per account, plus switch history
- [x] Export history as CSV
- [x] **Explained account recommendations** ("Work: most 5-hour headroom"), consistent with `cswap switch --strategy best`
- [x] Optional **auto-switch** that runs `cswap auto --json` and follows its events, refreshing as soon as CSwap switches

## 🎯 1.0: Polished release

- [ ] **Notarized** builds and an official **Homebrew cask**. This needs an Apple Developer Program membership; sponsorship welcome.
- [ ] Signed update feeds (Sparkle, EdDSA) on top of the current checksum-verified GitHub updates
- [ ] Localization groundwork · *help wanted*
- [ ] Accessibility audit (VoiceOver, keyboard navigation, Reduce Motion)
- [ ] Universal binary (Apple Silicon and Intel) in releases

## 💡 Later / exploring

- **WidgetKit widgets** for Notification Center, alongside the in-app desktop widgets. Needs an Xcode project target and app-group signing.
- **Windows and Linux** companions, for example a Tauri tray app reusing the same CSwap JSON contract. CSwap itself is cross-platform.
- Per-account notes and colors

## Not planned

- Storing Claude credentials or talking to Anthropic APIs directly. CSwap stays the source of truth.
- A cloud backend or telemetry.
