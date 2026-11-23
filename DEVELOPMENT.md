# Development Guide

Everything you need to build, run, test, and release CSwapBar. For ground rules and the pull-request process, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Quick start

```bash
git clone https://github.com/iamv1n/CSwapBar.git
cd CSwapBar
./scripts/setup.sh --run
```

`setup.sh` checks your Mac (macOS 14+, Xcode or the Command Line Tools, Swift 6+). If CSwap is missing, it offers to install it. It then builds the app, runs the tests, and (with `--run`) launches a debug build into your menu bar. It's safe to re-run.

| Flag | Effect |
| --- | --- |
| `--run` | Launch a debug build when done |
| `--install` | Build the `.app` and install it to `/Applications` |
| `--yes` | Don't prompt (install CSwap if it's missing) |
| `--skip-tests` / `--skip-cswap` | Skip those steps |

### Requirements

- macOS 14 Sonoma or later
- Swift 6: **Command Line Tools** (`xcode-select --install`) or **Xcode**. Xcode is optional; you only need it for SwiftUI Previews and Instruments.
- [CSwap](https://github.com/realiti4/claude-swap) 1.1.0+ to see real accounts (`uv tool install claude-swap`). Unit tests don't need it.

### Editors

Any editor works. In VS Code, Cursor, or Antigravity, install the official **Swift** extension for completion and debugging (it uses `sourcekit-lsp` and `lldb-dap` from your toolchain). If you switch toolchains (for example with `xcode-select -s`), restart the extension.

## Everyday commands

```bash
swift run CSwapBar                           # run from source (menu-bar app)
swift build                                  # debug build
./scripts/test.sh                            # unit tests
./scripts/test.sh --filter Privacy           # one suite
CSWAPBAR_INTEGRATION=1 ./scripts/test.sh     # + read-only tests against your real CSwap
./scripts/build.sh                           # build/CSwapBar.app (release, ad-hoc signed)
./scripts/install.sh                         # build + install to /Applications + launch
```

`scripts/test.sh` works with both Xcode and the Command Line Tools. With CLT-only, it adds the Swift Testing macro plugin path that the toolchain otherwise can't find.

## Project layout

```text
Sources/
├── CSwapBarCore/            UI-free logic. Unit-tested. No SwiftUI.
│   ├── CSwapAdapter/        CSwapCLIClient, JSON DTOs (schema v1), binary locator, dates
│   ├── ProcessManager/      ProcessRunner: no shell, timeouts, cancellation
│   ├── Accounts/            Account model, availability, paging, summary
│   ├── Usage/               Usage levels (color bands), countdowns
│   ├── Switching/           SwitchCoordinator: serialized, verified switches
│   ├── Privacy/             PrivacyPreferences, masking, AccountPresenter, safe text
│   ├── Appearance/          Theme palettes, accents, fonts, WCAG contrast
│   └── Settings/            AppSettings (lenient Codable), SettingsStore, layouts, widgets
└── CSwapBarApp/             The SwiftUI app
    ├── main.swift           AppKit entry point
    ├── CSwapBarApp.swift    AppDelegate
    ├── AppModel.swift       @Observable state: connection, accounts, refresh loop, settings
    ├── StatusItemController.swift   Menu-bar item, NSPopover, Settings window
    ├── DesignSystem/        Theme, typography, components, logo (LogoMark.swift)
    ├── Features/MenuBar/    Popover, account cards, usage views, pager
    ├── Features/Settings/   Settings window and pages
    ├── Features/Widgets/    Desktop widget views and panel controller
    └── Support/             Sample data, snapshot renderer
Tests/CSwapBarCoreTests/     Swift Testing suites + synthetic fixtures
Support/                     Info.plist template, AppIcon.icns
docs/                        Install guide, website, brand SVGs, README images
scripts/                     setup, build, test, install, package, release, make-icon, get
```

## Architecture in one minute

```text
cswap CLI ──(argv, no shell)──▶ ProcessRunner ──▶ CSwapCLIClient ──▶ DTOs ──▶ AccountMapper ──▶ Account
                                                         │
                                       SwitchCoordinator ┘ (list → switch → verify with status)

AppModel (@Observable, MainActor)
  ├─ refresh loop (every N s) ─▶ AccountSnapshot
  ├─ AppSettings ⇄ SettingsStore (UserDefaults JSON)
  └─ presentation(for:) ─▶ AccountPresenter (privacy masking) ─▶ views

StatusItemController ─▶ NSStatusItem + NSPopover(PopoverView) + Settings NSWindow
DesktopWidgetController ─▶ borderless NSPanels(DesktopWidgetView)
```

Key rules:

- **CSwap is the source of truth.** CSwapBar never touches credentials, and talks to CSwap only through `cswap … --json` (schema v1; unknown fields are ignored).
- **Views never mask identity themselves.** They render `AccountPresentation`, which applies the privacy rules in one place.
- **Every color comes from the theme** (`@Environment(\.theme)`). Nothing is hard-coded in views.

## Debugging & UI snapshots

The app binary has developer flags. They're handy because macOS won't let scripts click the menu bar.

```bash
BIN="$(swift build --show-bin-path)/CSwapBar"

# Render UI with fake sample accounts to PNG (no CSwap needed)
$BIN --render-popover out.png --accounts 6 --theme widgets --layout rings [--privacy] [--compact] [--light] [--size large] [--font rounded] [--per-page 3]
$BIN --render-settings out.png --pane appearance --theme midnight
$BIN --render-widget out.png --kind accounts --theme sky

# Run the real app and open things on launch
$BIN --open-popover --debug-layout           # logs the popover's real size
$BIN --open-settings --pane general
CSWAPBAR_CAPTURE=/tmp/shot $BIN --open-settings --pane layout   # writes /tmp/shot-settings.png
```

The snapshot renderer can't draw `ScrollView`s or some AppKit controls. For layout bugs that depend on the real window width, use `--open-settings` with `CSWAPBAR_CAPTURE`.

**Settings domains:** a debug binary (`swift run`) stores settings under the `CSwapBar` defaults domain, while the installed app uses `io.github.iamv1n.CSwapBar`. Experimenting in debug won't touch your real settings.

## Testing

- **Swift Testing** (`import Testing`, `@Test`, `#expect`). Suites live in `Tests/CSwapBarCoreTests`.
- **Fixtures are synthetic** (`Fixtures.swift`) and mirror CSwap 1.1.0's real JSON shapes. Never paste real account data.
- **Integration tests** (`CSwapIntegrationTests.swift`) are opt-in with `CSWAPBAR_INTEGRATION=1` and **read-only**. They must never switch, add, or remove accounts.
- **Theme contrast tests** check every palette and accent against WCAG ratios. If you add a theme, the tests tell you if it isn't readable.

## Common tasks

### Add a theme

1. Add a case to `ThemeChoice` and a `ThemePalette` in `Sources/CSwapBarCore/Appearance/ThemePalette.swift`. Assign the case to a group, and give it a title and tagline.
2. Add the palette to `ThemePalette.all`.
3. Run `./scripts/test.sh --filter Themes` and adjust colors until the contrast tests pass.
4. Check it: `$BIN --render-popover /tmp/t.png --theme <yourTheme>`.

### Add a setting

1. Add a property to `AppSettings`, and decode it leniently in `init(from:)` so older settings files keep working.
2. Add a test in `AccountPagingTests.swift` or `PrivacyTests.swift` (persistence and unknown values).
3. Add a row to the right Settings page (`Features/Settings/SettingsView.swift`) using `SettingsRow` with `ThemedSegmented` or `.toggleStyle(.themedSwitch)`.

### Change the logo

Edit the geometry in `DesignSystem/LogoMark.swift` (`TriadGeometry`) and keep `docs/brand/*.svg` in sync. Then run `./scripts/make-icon.sh` to regenerate `Support/AppIcon.icns`.

## Versioning & releases

- **Semantic Versioning.** The single source of truth is the [`VERSION`](VERSION) file; `build.sh` stamps it into the app's Info.plist.
- **[CHANGELOG.md](CHANGELOG.md)** follows Keep a Changelog. Add user-visible changes under `## [Unreleased]` in your PR.

Releases are published by hand. No tokens or secrets are needed anywhere.

```bash
./scripts/release.sh 0.2.0           # runs tests, bumps VERSION, dates the changelog, commits, tags v0.2.0
git push origin main --follow-tags
./scripts/package.sh                 # → dist/CSwapBar-0.2.0.dmg, .zip, and .sha256 files
```

Then, on GitHub: **Releases → Draft a new release**. Pick the `v0.2.0` tag, paste that version's section from `CHANGELOG.md`, and add the first-launch note from [docs/INSTALL.md](docs/INSTALL.md). Attach the four files from `dist/`, then publish.

The DMG contains the app, an Applications shortcut, and an "If CSwapBar won't open" help file. Releases are ad-hoc signed and not notarized (no paid Apple Developer account), so users follow [docs/INSTALL.md](docs/INSTALL.md) to allow the first launch.


## Website

The project site is a static page in [`docs/`](docs/) (`index.html`, `styles.css`, `app.js`). It has no build step and reuses `docs/images` and `docs/brand`.

```bash
python3 -m http.server 8000 -d docs   # preview at http://localhost:8000
```

To publish on GitHub Pages: **Settings → Pages → Build and deployment → Source: Deploy from a branch → `main` / `/docs`**. It goes live at `https://iamv1n.github.io/CSwapBar/`. `docs/.nojekyll` makes GitHub serve the files as they are.

## Checks before pushing

There's no hosted CI. Run the same checks locally before you push or open a PR:

```bash
for f in scripts/*.sh; do bash -n "$f"; done   # shell syntax
./scripts/test.sh                              # build + tests
./scripts/build.sh                             # app bundle assembles
```
