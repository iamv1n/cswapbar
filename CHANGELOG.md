# Changelog

All notable changes to CSwapBar are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before 1.0, minor versions (0.x.0) may include breaking changes to settings or behavior.

## [Unreleased]

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

[Unreleased]: https://github.com/iamv1n/CSwapBar/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/iamv1n/CSwapBar/releases/tag/v0.1.0
