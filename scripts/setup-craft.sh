#!/usr/bin/env bash
#
# Build the pinned Craft runtime and print its path.
#
# Craft is not installable in CI: `pantry install craft` resolves it to
# craft-native.org, which the installer SDK skips, and the newest craft the
# pantry registry and the GitHub releases carry is 0.0.37 — the last build
# produced before Actions were disabled for the home-lang organisation.
# Everything Hush needs (`--html-file`, the focus and screenSharing bridges)
# landed after that.
#
# So we build it, from the exact tag recorded in craft.config.ts. That pins the
# runtime as firmly as a package version would and does not depend on someone
# else's release pipeline being healthy.
#
# Usage:  eval "$(scripts/setup-craft.sh)"   — exports CRAFT_BIN
#         scripts/setup-craft.sh --path      — prints the binary path only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(bun --print "(await import('$ROOT/craft.config.ts')).config.craftVersion")"
CHECKOUT="$ROOT/.craft/$VERSION"
BINARY="$CHECKOUT/packages/zig/zig-out/bin/craft"

if [ ! -x "$BINARY" ]; then
  if [ ! -d "$CHECKOUT/.git" ]; then
    rm -rf "$CHECKOUT"
    mkdir -p "$(dirname "$CHECKOUT")"
    git clone --depth 1 --branch "v$VERSION" \
      https://github.com/home-lang/craft.git "$CHECKOUT" >&2
  fi

  # Craft's own pantry manifest pins the Zig it builds with, so activating its
  # environment rather than the host's is what makes this reproducible.
  cd "$CHECKOUT/packages/zig"
  eval "$(cd "$CHECKOUT" && pantry env | sed -n '/^export /,$p')"
  zig build -Doptimize=ReleaseSafe -Dversion="$VERSION" >&2
fi

if [ "${1:-}" = "--path" ]; then
  echo "$BINARY"
else
  echo "export CRAFT_BIN=$BINARY"
fi
