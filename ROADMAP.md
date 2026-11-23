# Roadmap

Where CSwapBar is headed. Plans change. Open an [issue](https://github.com/iamv1n/CSwapBar/issues) to suggest something or to pick up an item; items marked **help wanted** are good places to start.

## ✅ 0.1: Foundation (released)

- CSwap integration: detection, version check, schema-v1 JSON, read-only integration tests
- Menu-bar popover with paging and content-fitted height
- Verified one-click switching
- Privacy Mode and individual privacy controls
- Four card layouts, 23 themes, accent colors, and typography options
- Desktop widgets (Gauge, Active Account, All Accounts)
- Settings window, logo and app icon, DMG releases

## 🔜 0.2: Daily driver

- [ ] **Launch at login** toggle (`SMAppService`)
- [ ] **Notifications** for usage thresholds (80% / 95% / 100%), switch results, and accounts that need login. They respect Privacy Mode; the notification text is already implemented and tested.
- [ ] **Global Privacy Mode shortcut** that works anywhere, not only while the popover is open
- [ ] **Configurable usage thresholds** (the color bands)
- [ ] Detect `cswap menubar` running at the same time and explain what that means
- [ ] CSwap executable path override in Settings → General · *help wanted*

## 🗓 0.3: History & insight

- [ ] **Usage history** in local SQLite: 30-day retention, account IDs hashed, never emails
- [ ] **Dashboard window** with Swift Charts: usage over time per account, plus switch history
- [ ] Export history as CSV
- [ ] **Explained account recommendations** ("Work: most 5-hour headroom"), consistent with `cswap switch --strategy best`
- [ ] Follow `cswap auto --json` events to reflect CSwap's own auto-switching without extra polling

## 🎯 1.0: Polished release

- [ ] **Notarized** builds and an official **Homebrew cask**. This needs an Apple Developer Program membership; sponsorship welcome.
- [ ] In-app updates (Sparkle, EdDSA-signed)
- [ ] Localization groundwork · *help wanted*
- [ ] Accessibility audit (VoiceOver, keyboard navigation, Reduce Motion)
- [ ] Universal binary (Apple Silicon and Intel) in releases

## 💡 Later / exploring

- **WidgetKit widgets** for Notification Center, alongside the in-app desktop widgets. Needs an Xcode project target and app-group signing.
- **Windows and Linux** companions, for example a Tauri tray app reusing the same CSwap JSON contract. CSwap itself is cross-platform.
- Custom user themes (import/export a palette)
- Per-account notes and colors

## Not planned

- Storing Claude credentials or talking to Anthropic APIs directly. CSwap stays the source of truth.
- A cloud backend or telemetry.
