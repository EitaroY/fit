# Contributing to Fit

Thanks for your interest! Fit aims to stay small, dependency-free, and easy to audit.

## Contributor License Agreement (CLA)

Fit is dual-licensed: the repository is GPL-3.0, and the copyright holder additionally distributes an official build through the Mac App Store, which the GPL alone does not permit. For that to stay legal, every contribution must be usable under both distribution channels.

**By submitting a pull request or patch, you agree that:**

1. The contribution is your own work and you have the right to license it.
2. Your contribution is licensed to the project under GPL-3.0, **and**
3. You additionally grant Eitaro Yamatsuta a perpetual, worldwide, non-exclusive, royalty-free, irrevocable license to use, reproduce, modify, sublicense, and relicense your contribution, including in the Mac App Store build and other non-GPL distributions.

If you're not comfortable with this, please open an issue describing the change instead of a PR — it can then be implemented independently.

## Ground rules

- **No third-party dependencies.** Building must keep working offline with a plain Xcode install.
- **Keep the core pure.** Geometry and zone logic lives in `Fit/Core/` with no AppKit imports, so it stays unit-testable via `swift test`.
- **macOS 13+ / Xcode 16+** are the supported baselines.

## Development

```sh
open Fit.xcodeproj   # build & run the app (⌘R)
swift test           # run core unit tests without the Xcode GUI
```

New source files under `Fit/` are picked up automatically (the project uses Xcode's synchronized folders) — no project-file editing needed.

## Pull requests

For anything bigger than a small fix, please open an issue first so the approach can be agreed on before you invest time.

1. Add or update unit tests for any change to `Fit/Core/`.
2. Make sure `swift test` and a Debug build both pass.
3. Describe the user-visible behavior change in the PR description.

## Demo animations

The animated SVGs under `docs/` (`demo.svg`, `demo-cycle.svg`) are generated. To edit them, change [scripts/generate-demos.py](scripts/generate-demos.py) and rerun it:

```sh
python3 scripts/generate-demos.py
```

Do not hand-edit the SVG files — the generator will overwrite them next time.

## Design docs

The detailed design lives in [docs/DESIGN.ja.md](docs/DESIGN.ja.md) (Japanese). Please keep it in sync when changing architecture-level behavior.

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). Security issues go through the [security policy](SECURITY.md), not public issues.
