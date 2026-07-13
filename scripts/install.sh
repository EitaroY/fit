#!/usr/bin/env bash
# scripts/install.sh — one-command "build and install permanently".
#
# WHY THIS EXISTS
# ---------------
# Xcode ⌘R produces an ad-hoc signature that changes on every rebuild.
# macOS ties the Accessibility grant to the code signature, so plain
# rebuilds silently lose their permission and Fit stops working until
# you re-add it in System Settings.
#
# This script solves that once and for all by creating a self-signed
# code-signing certificate ("Fit Dev") in your login keychain and using
# it to sign every build. The signature stays stable, so the grant
# stays valid across rebuilds. `git pull && ./scripts/install.sh` is
# then the complete update flow.
#
# ONE-TIME PROMPTS on first run
# -----------------------------
#   1. Keychain password / Touch ID — to import the private key.
#   2. Keychain password / Touch ID — to mark the certificate as trusted
#      for code signing (the trust setting is what makes the identity
#      usable).
# Subsequent runs are fully unattended.
#
# USAGE
# -----
#   ./scripts/install.sh              # build, sign, install to /Applications, launch
#   ./scripts/install.sh --uninstall  # remove installed app; the cert stays

set -euo pipefail

CERT_NAME="Fit Dev"
APP_NAME="Fit"
INSTALL_DIR="/Applications"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

info() { printf "\033[1;34m▸\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

# --- --uninstall flag -------------------------------------------------------

if [ "${1:-}" = "--uninstall" ]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    removed=0
    for dir in "$INSTALL_DIR" "$HOME/Applications"; do
        if [ -d "$dir/$APP_NAME.app" ]; then
            rm -rf "$dir/$APP_NAME.app" 2>/dev/null \
                || sudo rm -rf "$dir/$APP_NAME.app"
            ok "Removed $dir/$APP_NAME.app"
            removed=1
        fi
    done
    [ $removed = 1 ] || warn "No installed copy of $APP_NAME.app found."
    warn "'$CERT_NAME' certificate remains in your login keychain."
    warn "Remove it in Keychain Access if you're done with Fit for good."
    exit 0
fi

# --- 1. Ensure the signing identity exists ---------------------------------

setup_cert() {
    # Fully usable = listed by find-identity AND not annotated "Invalid".
    # A cert flagged "(Invalid Key Usage for policy)" or similar is present
    # but codesign will still refuse to use it, so we treat it as unusable.
    if security find-identity -v -p codesigning 2>/dev/null \
        | grep -F "\"$CERT_NAME\"" | grep -qv "Invalid"; then
        ok "Signing identity '$CERT_NAME' is already set up"
        return
    fi

    # If a certificate with this name is in the keychain but doesn't form a
    # usable identity, an earlier attempt left it in a bad state (missing
    # private key, missing trust, wrong extensions). Wipe and start fresh.
    if security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; then
        info "Removing an earlier '$CERT_NAME' entry before starting fresh"
        while security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; do
            security delete-certificate -c "$CERT_NAME" >/dev/null 2>&1 || break
        done
    fi

    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN
    local cert_pem="$tmpdir/cert.pem"

    info "Creating self-signed code-signing certificate '$CERT_NAME'"
    # OpenSSL config in a file (not -addext) for portability across versions.
    # extendedKeyUsage=codeSigning is what makes this an "identity for code
    # signing"; keyUsage=digitalSignature is what makes it *satisfy* the
    # code-signing policy (a cert with the EKU but no KU is listed as
    # "Invalid Key Usage for policy" and codesign refuses to use it).
    cat > "$tmpdir/openssl.cnf" <<CONF
[req]
distinguished_name = req_dn
x509_extensions = v3_ext
prompt = no

[req_dn]
CN = $CERT_NAME

[v3_ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
subjectKeyIdentifier = hash
CONF
    openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
        -config "$tmpdir/openssl.cnf" -extensions v3_ext \
        -keyout "$tmpdir/key.pem" -out "$cert_pem" \
        >/dev/null 2>&1 \
        || die "openssl failed to generate the certificate"

    # -legacy: PKCS12 in the older PBE format Apple's Security framework
    # accepts (OpenSSL 3 defaults trip a "MAC verification failed" import).
    # -A: give every app on this system access to the key. This is a
    # user-scoped keychain, and the private key never leaves it.
    openssl pkcs12 -export -legacy -passout pass:tmp \
        -inkey "$tmpdir/key.pem" -in "$cert_pem" \
        -name "$CERT_NAME" -out "$tmpdir/bundle.p12" \
        >/dev/null 2>&1 \
        || die "openssl failed to bundle the p12"

    info "Importing the certificate into your login keychain (may prompt for your password)"
    security import "$tmpdir/bundle.p12" \
        -k "$KEYCHAIN" -P "tmp" -A \
        >/dev/null \
        || die "keychain import failed"

    info "Marking '$CERT_NAME' as trusted for code signing (may prompt for your password)"
    # trustRoot (not trustAsRoot): the cert is self-signed, so it IS a root.
    # macOS rejects trustAsRoot for self-signed certs with a "parameters not
    # valid" error — that flag is only for non-root certs that you want to
    # treat as roots. -p codeSign scopes the trust to code signing only,
    # so this cert cannot silently authenticate anything else.
    security add-trusted-cert -r trustRoot -p codeSign \
        -k "$KEYCHAIN" "$cert_pem" \
        || die "trust setting was rejected — check Keychain Access, or grant trust manually there"

    security find-identity -v -p codesigning 2>/dev/null | grep -qF "\"$CERT_NAME\"" \
        || die "trust set, but identity still not recognized. Check Keychain Access."

    ok "Certificate ready for code signing"
    echo
    warn "FIRST-TIME REMINDER — after this run:"
    warn "  System Settings → Privacy & Security → Accessibility"
    warn "  Remove the old 'Fit' entry (−) and add the newly-signed one."
    warn "  From then on, rebuilds keep the grant."
    echo
}

setup_cert

# --- 2. Build --------------------------------------------------------------

build_dir="$repo_root/build"
build_log="$build_dir.log"

info "Building Fit (Release)"
rm -rf "$build_dir"
mkdir -p "$(dirname "$build_log")"
# Let the build use the project's default ad-hoc signing — asking xcodebuild
# to use a self-signed identity directly via CODE_SIGN_IDENTITY makes it
# demand a matching Apple team and refuse the build. We re-sign the finished
# bundle with the stable identity below; TCC only cares about the final
# signature on the app, not what Xcode used mid-build.
if ! xcodebuild -project Fit.xcodeproj -scheme "$APP_NAME" -configuration Release \
        -derivedDataPath "$build_dir" \
        build > "$build_log" 2>&1; then
    tail -40 "$build_log" >&2
    die "Build failed. Full log: $build_log"
fi

built_app="$build_dir/Build/Products/Release/$APP_NAME.app"
[ -d "$built_app" ] || die "Build product missing: $built_app"

info "Signing with '$CERT_NAME' for a stable code signature"
codesign --force --sign "$CERT_NAME" "$built_app" \
    || die "codesign failed — is 'Fit Dev' still in your keychain and trusted for code signing?"

sig=$(codesign -dvv "$built_app" 2>&1 || true)
echo "$sig" | grep -qF "Authority=$CERT_NAME" \
    || die "signature verification failed — '$CERT_NAME' didn't stick to the bundle"
ok "Built and signed"

# --- 3. Install ------------------------------------------------------------

info "Stopping any running Fit"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

dest="$INSTALL_DIR"
if [ ! -w "$dest" ]; then
    if sudo -n true 2>/dev/null; then
        info "Installing to $dest (via cached sudo)"
        sudo rm -rf "$dest/$APP_NAME.app"
        sudo cp -R "$built_app" "$dest/"
    else
        dest="$HOME/Applications"
        mkdir -p "$dest"
        warn "/Applications not writable; installing to $dest instead"
        rm -rf "$dest/$APP_NAME.app"
        cp -R "$built_app" "$dest/"
    fi
else
    rm -rf "$dest/$APP_NAME.app"
    cp -R "$built_app" "$dest/"
fi
ok "Installed $dest/$APP_NAME.app"

# --- 4. Launch --------------------------------------------------------------

info "Launching"
open -a "$dest/$APP_NAME.app"
sleep 1
if pgrep -x "$APP_NAME" > /dev/null; then
    ok "Fit is running (pid $(pgrep -x $APP_NAME))"
    echo
    echo "Menu bar → look for the split-rectangle icon."
    echo "If Accessibility isn't granted yet, the onboarding window will guide you."
else
    die "Fit did not start. Check Console.app for 'Fit' if this persists."
fi
