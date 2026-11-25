# Security Policy

## Supported versions

Only the latest release gets security fixes.

## Reporting a vulnerability

**Please don't open a public issue for security problems.** Use GitHub's private reporting instead: **Security → Report a vulnerability** on the [repository page](https://github.com/iamv1n/cswapbar/security/advisories/new).

Please include:

- What the issue is and its impact
- Steps to reproduce, with redacted data only (no real tokens, emails, or organization names)
- Your CSwapBar, CSwap, and macOS versions

You'll get an acknowledgement within a few days. Once a fix is released, you'll be credited unless you'd rather not be.

## Scope

CSwapBar is a front end for the CSwap CLI. By design, it:

- Never reads, stores, or transmits Claude credentials. CSwap handles authentication.
- Runs `cswap` directly with an argument list (never through a shell), with timeouts.
- Stores only display preferences locally (UserDefaults). There's no network backend and no telemetry.
- Keeps usage history (if enabled) in `~/Library/Application Support/CSwapBar/history.sqlite`: usage percentages, timestamps and switch records, with accounts stored as salted SHA-256 keys. No emails, names, or organizations. Deleted after 30 days, or on demand.
- Runs `cswap auto` only when you turn on auto-switch. It runs under a small `/bin/sh` watchdog (the one place a shell is used) that stops it when CSwapBar exits; arguments are passed as positional parameters, never interpolated.
- Makes one kind of network request: the update check, an anonymous `GET` to GitHub's public releases API (daily, and can be turned off in Settings → General). It sends nothing about you or your accounts.
- Installs updates only after verifying them: the release `.zip` and its `.sha256` file are downloaded over HTTPS from github.com, the SHA-256 digest must match, and the unpacked app must have CSwapBar's bundle ID, the advertised version, and an intact code signature. Releases are ad-hoc signed, not notarized, so the checksum and HTTPS are what vouch for a download. Notarized builds and signed (EdDSA) update feeds are planned for 1.0.

Issues inside CSwap itself (logins, token storage, switching) belong in the [CSwap project](https://github.com/realiti4/claude-swap).

Privacy Mode hides information on screen. It isn't a security boundary against someone with access to your Mac.
