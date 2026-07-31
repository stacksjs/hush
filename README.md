<p align="center"><img src=".github/cover.jpg" alt="Social Card of this repo"></p>

[![CI Status](https://github.com/stacksjs/hush/workflows/CI/badge.svg)](https://github.com/stacksjs/hush/actions/workflows/ci.yml)
[![Release Status](https://github.com/stacksjs/hush/workflows/Release/badge.svg)](https://github.com/stacksjs/hush/actions/workflows/release.yml)
<!-- [![npm downloads][npm-downloads-src]][npm-downloads-href] -->
<!-- [![Codecov][codecov-src]][codecov-href] -->

# Hush

> Silences your Mac while you share your screen. A menubar app built on Stacks — stx for the UI, Craft for the native runtime.

## Features

- 🎯 **Detection that means something** — matches the sharing *indicator* a conferencing app shows while a share is live, not the mere presence of the app
- 🔕 **Automatic Focus** — turns Do Not Disturb on when you start presenting, off when you stop
- 🌊 **No flapping** — transitions are debounced in both directions, so a sharing toolbar that rebuilds mid-meeting doesn't unsilence your Mac
- 🤝 **Leaves your Focus alone** — never turns off a Focus it didn't turn on
- 📊 **Usage statistics** — sessions, total quiet time, average session length
- 🚀 **Launch at login** — optional, and reconciled with what you set in System Settings
- 🔒 **Local only** — nothing leaves your Mac

## How detection works

macOS offers no "is my screen being captured?" API, so Hush combines four
independent signals through Craft:

| Signal | Fires when |
| --- | --- |
| System screen sharing | macOS Screen Sharing / Apple Remote Desktop has the session |
| Remote session | the session is driven from somewhere other than this console |
| Conference sharing | a conferencing app is showing its live sharing control |
| Screen recording | a recorder is capturing the screen |

The two window-level signals match the floating control an app shows *only
while sharing*. "Zoom is running" describes most of a working day, and acting
on it would silence notifications permanently.

## Setup

macOS reserves direct Focus control for Apple-entitled clients — Control
Center and Shortcuts hold the entitlement; third-party apps cannot. The one
sanctioned path is to let Shortcuts perform the change, so Hush needs two
shortcuts, created once:

1. Open **Shortcuts** and create a shortcut named **Hush Focus On**
2. Add the **Set Focus** action, set to turn Do Not Disturb **on**
3. Create a second shortcut named **Hush Focus Off** that turns it **off**

Hush checks for both at launch and tells you if either is missing, rather than
failing at the moment a meeting starts. You can point it at different names in
`~/Library/Application Support/Hush/preferences.json`.

## Requirements

- macOS 13.0 or later
- Bun 1.2 or later *(for development)*

## Development

```bash
bun install
bun run dev        # build and launch, with Craft's output in your terminal
bun run test
bun run build      # dist/Hush.app
bun run package    # dist/Hush.app + dist/Hush-<version>.dmg
```

The build resolves the Craft runtime from pantry, or from `CRAFT_BIN` when you
are working against a local Craft build:

```bash
CRAFT_BIN=~/Code/Tools/craft/packages/zig/zig-out/bin/craft bun run package
```

## Architecture

```
src/core/       platform-free: the decision engine, preferences, statistics
src/runtime/    the controller wiring detection → policy → Focus, and storage
src/client/     binds the controller to the popover
src/app.stx     the UI
scripts/        build and dev drivers
```

`src/core` has no imports outside itself, which is why the policy is covered
by tests that need neither a window nor a Mac.

## Releasing

```bash
bun run release:patch   # or release:minor / release:major
```

bumpx bumps the version, commits, tags and pushes. The tag triggers the release
workflow, which produces two artifacts from the same build:

- **Direct download** — hardened-runtime, Developer ID signed, notarized and
  stapled, published as a GitHub release with generated notes and a checksums
  manifest through the pantry action.
- **Mac App Store** — sandboxed, distribution signed, wrapped in a `.pkg` by
  `scripts/package-appstore.sh` and uploaded to App Store Connect.

Both steps are conditional on their secrets. Without them the release still
completes as an unsigned direct download and says so, rather than failing.

### Secrets

| Secret | Used for |
| --- | --- |
| `APPLE_APPLICATION_CERTIFICATE` | Developer ID signing (direct download) |
| `APPLE_CERTIFICATE_PASSWORD` | password for the `.p12` files |
| `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID` | notarization |
| `APPLE_DISTRIBUTION_CERTIFICATE` | Apple Distribution signing (store) |
| `APPLE_INSTALLER_CERTIFICATE` | 3rd Party Mac Developer Installer |
| `APPLE_PROVISIONING_PROFILE` | embedded in the store bundle |
| `APP_STORE_CONNECT_API_KEY_ID`, `..._ISSUER_ID`, `..._PRIVATE_KEY` | the upload |

Certificates and profiles are base64-encoded.

### Why the two builds differ

They are not the same binary signed twice. The store requires the App Sandbox,
and the sandbox forbids spawning `/usr/bin/shortcuts` — the mechanism the
direct build uses to set Focus. Craft detects the sandbox and switches to
`shortcuts://run-shortcut`, which LaunchServices permits. The entitlements are
separate documents for the same reason.

The store also requires `CFBundleExecutable` to be a Mach-O image, so Craft is
the bundle's executable and reads `Resources/craft.json` beside it. There is no
launcher script. CI asserts this shape on every push.

### Known limitations under the sandbox

- Shortcuts cannot be enumerated, so Hush cannot verify the Focus shortcuts
  exist. It reports "unknown" and stays quiet rather than prompting someone who
  has already done the setup.
- Running a shortcut by URL is fire-and-forget: macOS confirms the request
  reached Shortcuts, never that the shortcut ran.
