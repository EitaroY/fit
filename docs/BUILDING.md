# Building, signing, and permissions

## Requirements

- macOS 13 Ventura or later
- Xcode 16 or later (full Xcode, not just Command Line Tools, for the app build)
- No Apple ID, no paid developer account, no network access needed

## Recommended: `./scripts/install.sh`

```sh
./scripts/install.sh
```

Does everything in one command: creates a self-signed code-signing certificate on first run, builds Release, signs the app with it, installs to `/Applications`, and launches. Later runs reuse the certificate, so the signature stays byte-stable — macOS keeps trusting your Accessibility grant across `git pull && ./scripts/install.sh`.

On the very first run you'll get two macOS password prompts:

1. **Importing the private key** into your login keychain.
2. **Marking the certificate as trusted for code signing** (this is what makes the identity usable — a raw import isn't enough).

Everything after that is silent. To remove the app later, run `./scripts/install.sh --uninstall`.

## Build with Xcode

```sh
open Fit.xcodeproj
```

Press **⌘R**. The project is configured with *Sign to Run Locally* (ad-hoc signing), so it builds and runs with zero signing setup — but the signature changes every rebuild, so Accessibility permission has to be re-granted each time. Fine for one-off dev iterations; use the install script for anything you want to keep around.

## Build from the command line

```sh
# Debug build
xcodebuild -project Fit.xcodeproj -scheme Fit -configuration Debug build

# Release build into ./build
xcodebuild -project Fit.xcodeproj -scheme Fit -configuration Release \
  -derivedDataPath build build
# → build/Build/Products/Release/Fit.app
```

Core-logic unit tests (no Xcode GUI, works with Command Line Tools alone):

```sh
swift test
```

## Granting Accessibility permission

Fit moves other apps' windows via the macOS Accessibility API, which requires a one-time grant:

1. Launch Fit. The onboarding window appears.
2. Click **Open System Settings** → *Privacy & Security → Accessibility*.
3. Enable **Fit** in the list. The onboarding window closes itself once access is granted.

Fit requests *only* Accessibility — no screen recording, no input monitoring, no network.

## Ad-hoc signing and the "permission stopped working" problem

With ad-hoc signing, the code signature changes on **every rebuild**. macOS ties the Accessibility grant to the signature, so after rebuilding you may find the toggle ON but not working, or a duplicate entry appearing.

Fixes, in order of preference:

### Option A — Use the install script (permanent fix)

`./scripts/install.sh` (see top of this doc) sets up a stable self-signed certificate, so this problem goes away after one run.

### Option B — Re-add the entry (quick, per-rebuild)

System Settings → Privacy & Security → Accessibility → select Fit → remove it with **−** → launch Fit again and re-grant.

Or from a terminal:

```sh
tccutil reset Accessibility dev.temma.fit
```

### Option C — Manual self-signed certificate (equivalent of the script)

If you'd rather set the certificate up by hand:

1. Open **Keychain Access** → menu *Keychain Access → Certificate Assistant → Create a Certificate…*
2. Name: `Fit Dev` — Identity Type: *Self-Signed Root* — Certificate Type: **Code Signing** → Create.
3. Build with `xcodebuild ... CODE_SIGN_IDENTITY="Fit Dev" CODE_SIGN_STYLE=Manual`, then copy the app to `/Applications`.
4. Remove any old Fit entry from the Accessibility list and grant once. From then on, rebuilds keep it.

## Manual smoke-test checklist

After significant changes, verify by hand (the AX / hotkey layers can't be unit-tested):

- [ ] ⌃⌥← / ⌃⌥→ snap a Finder window to each half; ⌃⌥Return maximizes; ⌃⌥⌫ restores the original frame
- [ ] Press ⌃⌥← three times: the window cycles ½ → ⅔ → ⅓; moving the window by hand resets the cycle
- [ ] Press ⌃⌥↑ three times: the window cycles top ½ → ⅔ → ⅓ heights
- [ ] Press ⌃⌥← then ⌃⌥↑: the window jumps to the top-left quarter (and the other seven perpendicular pairs land on the expected corners)
- [ ] Hold ⇧ while dragging to an edge: no preview appears and releasing does not snap
- [ ] Quarters (⌃⌥U/I/J/K) and thirds (⌃⌥D/F/G) land on the expected grid
- [ ] Drag a window to the left edge → preview appears → release → snaps to left half
- [ ] Drag to a corner → quarter preview; drag to bottom edge → thirds preview
- [ ] With two displays: ⌃⌥⌘→ moves the window to the next display, proportionally
- [ ] Change a shortcut in Settings → old combo dead, new combo works immediately
- [ ] Gap slider: set 16 → halves leave a visible gutter
- [ ] Quit and relaunch: settings persist

Tip: `Fit.app/Contents/MacOS/Fit -FitSuppressOnboarding YES` launches without the onboarding window (useful for scripted smoke tests).

## Uninstall

Quick path — the install script has an uninstall flag:

```sh
./scripts/install.sh --uninstall
```

Full manual cleanup, including settings and the permission entry:

```sh
osascript -e 'tell application "Fit" to quit' 2>/dev/null
rm -rf /Applications/Fit.app
defaults delete dev.temma.fit 2>/dev/null   # settings
tccutil reset Accessibility dev.temma.fit    # permission entry
```

To also remove the self-signed certificate, open **Keychain Access**, find `Fit Dev`, and delete it.
