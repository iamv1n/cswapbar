# Contributing to CSwapBar

Thanks for helping! Bug reports, ideas, docs, themes, and code are all welcome.

- **Set up and build:** see [DEVELOPMENT.md](DEVELOPMENT.md). The short version is `./scripts/setup.sh --run`.
- **What's planned:** see [ROADMAP.md](ROADMAP.md). Items marked *help wanted* are great first picks.
- **Be kind:** see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
- **Security issues:** report them privately. See [SECURITY.md](SECURITY.md).

## Ways to contribute

- **Report a bug or suggest a feature** with the issue templates. Redact emails and organization names; Privacy Mode (⇧⌘P) helps with screenshots.
- **Pick up a roadmap item.** Comment on its issue (or open one) so work isn't duplicated.
- **Improve docs or add a theme.** Small, focused PRs get merged fastest.

## Workflow

1. Fork the repo and create a branch from `main`: `feat/notifications`, `fix/popover-height`, or `docs/install`.
2. Make your change, with tests for any logic.
3. Run `./scripts/test.sh` and make sure it passes.
4. Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) if users will notice the change.
5. Open a pull request using the template. For UI changes, include before/after screenshots (made with sample data or Privacy Mode).

Commit messages: use a short imperative summary ("Add launch-at-login toggle"). [Conventional Commits](https://www.conventionalcommits.org/) prefixes (`feat:`, `fix:`, `docs:`) are welcome but not required.

## Ground rules

These keep CSwapBar safe and maintainable. Pull requests that break them will be asked to change.

- **CSwap is the source of truth.** CSwapBar never reads, stores, or copies Claude credentials. It talks to CSwap only through the `cswap` CLI and its `--json` output.
- **No shell.** Run `cswap` with an argument array through `ProcessRunner`. Never build a shell command string.
- **Lenient decoding.** CSwap's JSON contract is additive. Treat new fields as optional and ignore unknown ones. Adding support for a new `schemaVersion` is a deliberate change.
- **No real account data** in code, tests, fixtures, screenshots, or issues. Use `@example.com` addresses.
- **Integration tests are read-only.** Tests that run against a real CSwap must never switch, add, or remove accounts.
- **Logic goes in `CSwapBarCore`** (no SwiftUI, unit-tested). Views stay thin.
- **Privacy first.** Views render `AccountPresentation`, never raw identity fields, so Privacy Mode covers everything.
- **Readable themes.** New palettes must pass the WCAG contrast tests.
- **No Anthropic branding** in icons, artwork, or screenshots. The logo is original; keep it that way.
- **Keep it buildable without Xcode.** Everything must build and test with the Command Line Tools alone.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
