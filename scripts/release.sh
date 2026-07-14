#!/usr/bin/env bash
# scripts/release.sh — build, sign, notarize, and package Fit for direct
# distribution (BOOTH, Lemon Squeezy, GitHub Releases, …).
#
# Output: dist/Fit-<version>.dmg — Developer ID-signed, hardened-runtime,
# notarized, and stapled. Gatekeeper opens it on any Mac without warnings.
#
# ONE-TIME SETUP
# --------------
# 1. Create a "Developer ID Application" certificate (requires the paid
#    Apple Developer Program):
#      Xcode → Settings… → Accounts → select your Apple ID →
#      Manage Certificates… → + → Developer ID Application
# 2. Create an app-specific password at https://account.apple.com
#    (Sign-In and Security → App-Specific Passwords).
# 3. Store notarization credentials in the keychain (once):
#      xcrun notarytool store-credentials fit-notary \
#        --apple-id "<your Apple ID email>" \
#        --team-id 94HLRRY93H \
#        --password "<app-specific password>"
#
# USAGE
#   ./scripts/release.sh                  # full pipeline (sign + notarize)
#   ./scripts/release.sh --skip-notarize  # package only, for local testing
#
# ENV OVERRIDES
#   FIT_RELEASE_IDENTITY   signing identity (default: "Developer ID Application")
#   FIT_NOTARY_PROFILE     notarytool profile name (default: fit-notary)

set -euo pipefail

APP_NAME="Fit"
IDENTITY="${FIT_RELEASE_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${FIT_NOTARY_PROFILE:-fit-notary}"
SKIP_NOTARIZE=0
[ "${1:-}" = "--skip-notarize" ] && SKIP_NOTARIZE=1

info() { printf "\033[1;34m▸\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

# --- Preconditions -----------------------------------------------------------

if ! security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
    die "No '$IDENTITY' identity in the keychain. See ONE-TIME SETUP at the top of this script."
fi
if [ "$SKIP_NOTARIZE" = 0 ] && ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    die "notarytool profile '$NOTARY_PROFILE' not found. See ONE-TIME SETUP at the top of this script."
fi

version=$(xcodebuild -project Fit.xcodeproj -scheme "$APP_NAME" -configuration Release \
    -showBuildSettings 2>/dev/null | awk '$1 == "MARKETING_VERSION" {print $3; exit}')
[ -n "$version" ] || die "could not read MARKETING_VERSION from the project"
info "Releasing $APP_NAME $version (identity: $IDENTITY)"

dist="$repo_root/dist"
rm -rf "$dist"
mkdir -p "$dist"

# --- Build -------------------------------------------------------------------

info "Building Release"
build_log="$dist/xcodebuild.log"
xcodebuild -project Fit.xcodeproj -scheme "$APP_NAME" -configuration Release \
    -derivedDataPath "$dist/DerivedData" build > "$build_log" 2>&1 \
    || { tail -30 "$build_log" >&2; die "build failed (full log: $build_log)"; }
app="$dist/DerivedData/Build/Products/Release/$APP_NAME.app"
[ -d "$app" ] || die "build product missing: $app"

# --- Sign --------------------------------------------------------------------

# Re-sign from scratch: hardened runtime on, and no entitlements at all.
# The debug-only get-task-allow entitlement that a plain `xcodebuild build`
# injects would be rejected by the notary service; re-signing without
# --entitlements strips it. A secure timestamp is required for notarization
# (and needs network), so it's skipped in local-test mode.
info "Signing with hardened runtime"
if [ "$SKIP_NOTARIZE" = 1 ]; then
    codesign --force --options runtime --sign "$IDENTITY" "$app"
else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$app"
fi
codesign --verify --strict --verbose=2 "$app" >/dev/null 2>&1 || die "signature verification failed"
ok "Signed"

# --- Package -----------------------------------------------------------------

info "Creating disk image"
staging="$dist/staging"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
dmg="$dist/$APP_NAME-$version.dmg"
hdiutil create -volname "$APP_NAME $version" -srcfolder "$staging" -ov -quiet -format UDZO "$dmg"
ok "Created $(basename "$dmg")"

# --- Notarize ----------------------------------------------------------------

if [ "$SKIP_NOTARIZE" = 1 ]; then
    warn "Skipped notarization (--skip-notarize) — this dmg is for local testing only"
else
    info "Submitting to Apple's notary service (usually 1–5 minutes)"
    xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait \
        || die "notarization failed — inspect with: xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE"
    info "Stapling ticket"
    xcrun stapler staple "$dmg" >/dev/null
    xcrun stapler validate "$dmg" >/dev/null || die "staple validation failed"
    ok "Notarized and stapled"
fi

# --- Summary -----------------------------------------------------------------

echo
ok "Done: $dmg"
shasum -a 256 "$dmg"
if [ "$SKIP_NOTARIZE" = 0 ]; then
    echo "Upload this dmg to the sales page and/or GitHub Releases, then tag the repo (git tag v$version && git push --tags)."
fi
