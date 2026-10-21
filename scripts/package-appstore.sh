#!/usr/bin/env bash
#
# Sign the built app for the Mac App Store and wrap it in an installer package.
#
# Separate from the direct-download path on purpose. A store build is sandboxed,
# signed with distribution certificates and delivered as a .pkg; a direct
# download is hardened-runtime, Developer ID signed and delivered as a .dmg.
# Trying to produce one artifact that satisfies both produces neither.
#
# Expects `bun run build` to have run first.
#
# Environment:
#   APPLE_SIGNING_IDENTITY            "Apple Distribution: …" or
#                                     "3rd Party Mac Developer Application: …"
#   APPLE_INSTALLER_SIGNING_IDENTITY  "3rd Party Mac Developer Installer: …"
#   APPLE_PROVISIONING_PROFILE        matching App Store .provisionprofile
#   HUSH_DISTRIBUTION                 app-store (selects shared native signing)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HUSH_ROOT="$ROOT" export HUSH_ROOT
APP_NAME="$(bun --print "(await import(process.env.HUSH_ROOT + \"/craft.config.ts\")).config.name")"
VERSION="$(bun --print "JSON.parse(await Bun.file(process.env.HUSH_ROOT + \"/package.json\").text()).version")"

APP="dist/$APP_NAME.app"
PKG="dist/$APP_NAME-$VERSION.pkg"

if [[ ! -d "$APP" ]]; then
  echo "No app bundle at $APP — run 'bun run build' first." >&2
  exit 1
fi

for required in APPLE_SIGNING_IDENTITY APPLE_INSTALLER_SIGNING_IDENTITY; do
  if [[ -z "${!required:-}" ]]; then
    echo "$required is not set. A store package cannot be produced unsigned —" >&2
    echo "App Store Connect rejects the upload before it looks at anything else." >&2
    exit 1
  fi
done

# The store rejects a bundle whose CFBundleExecutable is a script, so fail here
# rather than after a ten-minute upload.
EXECUTABLE="$APP/Contents/MacOS/$APP_NAME"
if ! file -b "$EXECUTABLE" | grep -q 'Mach-O'; then
  echo "$EXECUTABLE is not a Mach-O image. The bundle was built in launcher" >&2
  echo "style, which the Mac App Store does not accept. Build against Craft" >&2
  echo "0.0.57 or newer, or set bundleStyle: 'executable'." >&2
  exit 1
fi

# The shared native packager embeds the matching profile and applies the
# distribution entitlements during assembly, before sealing the bundle.
if [[ "${HUSH_DISTRIBUTION:-}" != "app-store" || ! -f "$APP/Contents/embedded.provisionprofile" ]]; then
  echo "Build with HUSH_DISTRIBUTION=app-store and APPLE_PROVISIONING_PROFILE first." >&2
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "$APP"

# Confirm the sandbox actually landed. A store build without it is refused, and
# the failure message from App Store Connect does not say which entitlement is
# missing.
if ! codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -extract com.apple.security.app-sandbox raw - >/dev/null 2>&1; then
  echo "The signed bundle has no app-sandbox entitlement. Build with HUSH_DISTRIBUTION=app-store." >&2
  exit 1
fi

echo "Building $PKG…"
if [[ -e "$PKG" ]]; then
  echo "$PKG already exists; move it before producing another signed installer." >&2
  exit 1
fi
productbuild \
  --component "$APP" /Applications \
  --sign "$APPLE_INSTALLER_SIGNING_IDENTITY" \
  "$PKG"

pkgutil --check-signature "$PKG"
echo "✔ $PKG"
