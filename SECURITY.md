# Security Policy

## Supported versions

Only the latest release gets security fixes.

## Reporting a vulnerability

**Please don't open a public issue for security problems.** Use GitHub's private reporting instead: **Security → Report a vulnerability** on the [repository page](https://github.com/iamv1n/CSwapBar/security/advisories/new).

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

Issues inside CSwap itself (logins, token storage, switching) belong in the [CSwap project](https://github.com/realiti4/claude-swap).

Privacy Mode hides information on screen. It isn't a security boundary against someone with access to your Mac.
