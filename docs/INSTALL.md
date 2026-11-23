# Installing CSwapBar

CSwapBar is free and open source. Its releases are **not notarized by Apple**, because that requires a paid Apple Developer account. The app is safe to build and inspect yourself, but macOS will block it the first time you open it. This page explains how to allow it.

> Prefer no prompts at all? [Build from source](#option-c-build-from-source). An app you build yourself opens without any warning.

## Before you start

You need:

- macOS 14 Sonoma or later
- [CSwap](https://github.com/realiti4/claude-swap) 1.1.0 or later, with your accounts added:

  ```bash
  uv tool install claude-swap
  cswap add          # once per Claude account
  ```

## Option A: DMG from GitHub Releases (recommended)

1. Download `CSwapBar-<version>.dmg` from the [latest release](https://github.com/iamv1n/cswapbar/releases/latest).
2. **Optional: verify the download.** Compare the checksum with the `.sha256` file from the same release:

   ```bash
   shasum -a 256 ~/Downloads/CSwapBar-*.dmg
   ```

3. Open the DMG and drag **CSwapBar** onto **Applications**.
4. Eject the DMG.
5. Open CSwapBar from Applications, then allow it using the steps for your macOS version below.

### First launch on macOS 15 Sequoia or later

macOS will say *"CSwapBar" Not Opened* or *Apple could not verify "CSwapBar" is free of malware*. Click **Done**, not Move to Trash. Then:

1. Open **System Settings → Privacy & Security**.
2. Scroll down to **Security**. You'll see *"CSwapBar" was blocked to protect your Mac.*
3. Click **Open Anyway**, then enter your password.
4. In the dialog that appears, click **Open Anyway** again.

You only need to do this once. After that, CSwapBar opens normally.

### First launch on macOS 14 Sonoma

1. In Finder, open **Applications**.
2. **Right-click** (or Control-click) **CSwapBar** and choose **Open**.
3. Click **Open** in the dialog.

### Or use Terminal (any macOS version)

This removes the "downloaded from the internet" flag that triggers the prompt:

```bash
xattr -dr com.apple.quarantine /Applications/CSwapBar.app
open /Applications/CSwapBar.app
```

### "CSwapBar is damaged and can't be opened"

This message usually means the quarantine flag is set on an app that isn't notarized. The app itself isn't broken. Run the Terminal command above and open it again.

## Option B: one-line install from source

This clones the repository to `~/.cswapbar/src`, builds the app, and installs it to `/Applications`. It needs the Command Line Tools (`xcode-select --install`). Read the [script](../scripts/get.sh) first if you like:

```bash
curl -fsSL https://raw.githubusercontent.com/iamv1n/cswapbar/main/scripts/get.sh | bash
```

Run the same command again to update.

## Option C: build from source

```bash
git clone https://github.com/iamv1n/cswapbar.git
cd cswapbar
./scripts/install.sh
```

An app you build yourself has no quarantine flag, so it opens with no prompts.

## After installing

- Look for the CSwapBar icon in your **menu bar**. CSwapBar has no Dock icon.
- To start it at login, open **System Settings → General → Login Items** and add CSwapBar.
- If the popover says **CSwap not found**, install CSwap (see above) and click **Reconnect** in Settings → General.

## Updating

Download the new DMG and replace the app in Applications. You'll need to allow it once more, as described above, because each download is quarantined again. Your settings are kept.

## Uninstalling

1. Quit CSwapBar: open the popover and click **Quit** (or press ⌘Q).
2. Delete `/Applications/CSwapBar.app`.
3. **Optional:** remove its preferences:

   ```bash
   defaults delete io.github.iamv1n.CSwapBar
   ```

CSwapBar stores no accounts or credentials, so there's nothing else to clean up. Your accounts stay in CSwap.

## Why isn't it notarized?

Notarization needs an Apple Developer Program membership ($99/year). CSwapBar is a free hobby project, so releases are ad-hoc signed instead. If the project grows, notarized releases (and a Homebrew cask) are on the [roadmap](../ROADMAP.md).
