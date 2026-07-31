#!/usr/bin/env bash
#
# Build the pinned Craft runtime and print its path.
#
# Craft is not installable in CI: `pantry install craft` resolves it to
# craft-native.org, which the installer SDK skips with a warning, and the
# newest craft the pantry registry and the GitHub releases carry is 0.0.37 —
# the last build produced before Actions were disabled for the home-lang
# organisation. Everything Hush needs (`--html-file`, the focus and
# screenSharing bridges) landed after that.
#
# So we build it, from the exact tag recorded in craft.config.ts. That pins the
# runtime as firmly as a package version would and does not depend on someone
# else's release pipeline being healthy.
#
# Prints the binary path. When $GITHUB_ENV is set it also exports CRAFT_BIN for
# subsequent steps, so no caller ever has to eval its output.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUSH_ROOT="$ROOT" export HUSH_ROOT
VERSION="$(bun --print "(await import(process.env.HUSH_ROOT + \"/craft.config.ts\")).config.craftVersion")"
CHECKOUT="$ROOT/.craft/$VERSION"
BINARY="$CHECKOUT/packages/zig/zig-out/bin/craft"

if [[ ! -x "$BINARY" ]]; then
  if [[ ! -d "$CHECKOUT/.git" ]]; then
    rm -rf "$CHECKOUT"
    mkdir -p "$(dirname "$CHECKOUT")"
    git clone --depth 1 --branch "v$VERSION" \
    https://github.com/home-lang/craft.git "$CHECKOUT" >&2
  fi

  # Craft's own pantry manifest pins the Zig it builds with, so activating
  # its environment rather than the host's is what makes this reproducible.
  # Sourced from a file rather than eval'd: same effect, nothing re-parsed.
  ENV_FILE="$(mktemp)"
  trap 'rm -f "$ENV_FILE"' EXIT
  (cd "$CHECKOUT" && pantry env) | sed -n '/^export /,$p' > "$ENV_FILE"
  # shellcheck disable=SC1090
  source "$ENV_FILE"

  cd "$CHECKOUT/packages/zig"
  zig build -Doptimize=ReleaseSafe -Dversion="$VERSION" >&2
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "CRAFT_BIN=$BINARY" >> "$GITHUB_ENV"
fi

echo "$BINARY"
