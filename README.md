<p align="center"><img src=".github/cover.jpg" alt="Social Card of this repo"></p>

[![CI Status](https://github.com/stacksjs/hush/workflows/CI/badge.svg)](https://github.com/stacksjs/hush/actions/workflows/ci.yml)
[![Release Status](https://github.com/stacksjs/hush/workflows/Release/badge.svg)](https://github.com/stacksjs/hush/actions/workflows/release.yml)
<!-- [![npm downloads][npm-downloads-src]][npm-downloads-href] -->
<!-- [![Codecov][codecov-src]][codecov-href] -->

# Hush

> Silences your Mac while you share your screen. A menubar app built on Stacks — stx for the UI, Craft for the native runtime.

## Features

- **A native menu-bar home** — a compact, rounded popover with a custom Hush mark, native switches, automatic light and dark appearance, and Escape to dismiss

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

The two window-level signals match native indicators an app shows *only
while sharing*. Chrome window and screen sharing expose such a control.
For Chrome and Dia tab-only capture, Craft reads browser-owned native accessibility
sharing indicators after you grant Accessibility access. Discord and Slack use
their native voice and huddle controls with the same grant. Queries run on
a worker with bounded IPC timeouts so they cannot block the app’s UI. "Zoom is running" describes most of a working day, and acting
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

Chrome and Dia tab-only sharing, Discord, and Slack also need **Accessibility**
permission. Hush’s “Detect sharing controls” panel opens the native permission setup explicitly;
launching the app never requests this access.

Hush uses the bundle identity `com.stacksjs.hush`. When upgrading from an
`org.stacksjs.hush` build, macOS requires new permission grants and login-item
registration. Preferences and statistics stay in the same Hush application-support folder.

## Requirements

- macOS 13.0 or later
- Bun 1.3 or later, Pantry, and the macOS SDK from Command Line Tools *(for development)*

## Development

Hush is a Buddy-managed native Stacks app. Its UI runs in macOS WebKit inside
Craft; the bundle needs neither Bun nor a server at runtime.

```bash
bun install
bun run dev              # provisions the pinned runtime, then opens the native app
bun run build            # dist/Hush.app
bun run package          # dist/Hush.app + DMG
./buddy upgrade          # update the native app's declared packages
bun run verify           # build, types, unit tests, compiled client, real native bridge
```

Buddy asks Pantry to provision the pinned runtime for dev/build/package.
`./buddy dev`, `./buddy build`, and `./buddy package` use the same cached binary.

For Focus status, the signed app needs Apple's Communication Notifications
capability and a matching Developer ID provisioning profile. Set
`APPLE_SIGNING_IDENTITY` (the certificate SHA-1) and
`APPLE_PROVISIONING_PROFILE` (the profile path) in an ignored `.env.local`.
The shared stx packager embeds the profile and signs the assembled bundle.
Without signing configuration, development builds are ad-hoc signed and wait
for readable Focus status before automatic activation.

Pantry reads `APPLE_APPLICATION_CERTIFICATE`, `APPLE_CERTIFICATE_PASSWORD`,
and `APPLE_PROVISIONING_PROFILE_BASE64` from Buddy-encrypted `.env.production`.
It verifies the signed executable before publishing; missing signing setup
fails the release. Native checks never infer a live Focus transition from
successful startup or shortcut enumeration.

For platform development, point `CRAFT_BIN` at a source build in
`~/Code/Tools/craft`. Develop Buddy in `~/Code/stacks` and stx/desktop in
`~/Code/Libraries/stx` using Bun's package linking; fix those source repositories
and consume their releases. Hush contains application policy and UI.

`craft.config.ts` selects a live status-item popover with `trayPopover: true`.
Craft's `menubarOnly` mode creates no page and cannot run this controller.
The pinned runtime uses `ReleaseSmall` and disables Craft's separate CLI
JavaScript interpreter. The app's JavaScript continues to run on system WebKit.

Native verification exercises the shipped client inside real WebKit: startup,
filesystem round trips, screen-sharing state, shortcut enumeration, failed
Shortcut execution without blocking the UI, and clean shutdown. It also reads
the rendered macOS menu-bar title, tooltip and template image, and checks
the Focus and login switches against native state.
`test:native:app` also launches through LaunchServices to exercise macOS’s app
identity and permission context, including a 65-second hidden-WebKit background
timer check. Both native checks run in CI. The compiled-client suite separately verifies transitions and controls
against a deterministic bridge. Missing build artifacts fail the E2E suite.
For the installed app, `bun scripts/test-native.ts --app=/Applications/Hush.app --enable-login --background-ms=65000` enables the shipped login switch, verifies native registration, and checks the hidden app's timer. A subsequent run without `--enable-login` verifies the registration persists.
A live conferencing/Focus check also requires Screen Recording permission and
the two user-created shortcuts described above; the native report records
whether those shortcuts are installed. To verify a real window-sharing session
while preserving an existing Focus, run
`bun scripts/test-native.ts --observe-sharing`. With no Focus active,
`--exercise-focus` additionally verifies automatic activation and release against
macOS. These explicit live checks require the corresponding permissions and
installed shortcuts. Start sharing after the ready marker appears; follow the
stop protocol below when the active marker appears.
Add `--expect-tab-sharing` to require Chrome's or Dia's actual native tab-capture
indicator; a window-sharing signal cannot satisfy that check. `--verbose`
includes the native process output when diagnosing bridge failures.
`dist/live-sharing-ready.json` identifies the idle, permission-checked run that
is ready for capture; `dist/live-sharing-start.json` identifies the same run
after the native source and Focus checks settle, concurrent native reads agree,
and capture stays active for at least thirty seconds. Match their `checkedAt`
and artifact hash to the case report. Before operating the client's real Stop
Sharing control, write `dist/live-sharing-stop.json` with the active run's
`testCase`, `checkedAt`, and `stopRequestedAt: Date.now()`. The verifier rejects
any native stop before that request and then requires both the watcher and a
fresh native read to confirm sharing stopped.
Use `--expect-app=Dia --expect-source='Browser tab sharing' --case=dia-meet-tab`
for a Dia sharing cycle. `--expect-app` requires a source from that exact native
application; `--expect-source` also checks its native indicator. Each named case
writes a separate `dist/e2e/<case>.json` report. Live checks require an idle
starting state and a real start/stop cycle; app launch alone never counts as a
compatibility pass. Reports include the full signed bundle’s SHA-256, its executable’s SHA-256, and the
configured Craft revision; failed runs replace any earlier success for that case.

Run `bun run test:compatibility` after collecting `zoom-window`, `teams-window`,
`dia-local-tab`, `discord-window`, `slack-window`, `google-meet-dia`,
`chrome-local-tab`, and `google-meet-chrome` cases,
plus `zoom-automatic-focus-background` with `--exercise-focus` after waiting at
least one minute before starting capture.
Chrome's Meet check must keep the receiving Meet tab selected while sharing the
separate capture-check tab. Craft reads the browser-owned sharing banner even
when the captured tab is in the background; webpage text cannot satisfy it.
The gate requires all six clients’ real start/stop checks, Chrome tab capture
and Meet, the expected native app
source, existing Focus preservation, automatic activation/release after a
minute in the background, and the current signed artifact hash and Craft revision. Missing,
failed, or stale reports fail the gate. Live client checks require local signed-in
clients and are separate from the native bridge checks that run in CI.

## Architecture

```
src/core/       platform-free: the decision engine, preferences, statistics
src/runtime/    the controller wiring detection → policy → Focus, and storage
src/client/     binds the controller to the popover
src/app.stx     the UI
scripts/        app-specific native verification
pantry.json     runtime pins, capabilities, checks and release policy
```

`src/core` has no imports outside itself, which is why the policy is covered
by tests that need neither a window nor a Mac.

## Releasing

```bash
bun run release:patch   # or release:minor / release:major
```

Buddy delegates release qualification and versioning to Pantry, which runs the
app checks before bumpx commits, tags and pushes. The tag calls Pantry's
versioned native app workflow. `pantry.json` declares the pinned runtime,
capabilities, real native checks, size limit and release policy. Pantry installs
locked dependencies, builds the immutable Craft runtime with its locked Zig
compiler, compiles through Buddy, runs every check, signs with Developer ID,
notarizes and staples the DMG, verifies uploaded assets and creates a draft with
checksums and a notarization receipt. Missing required credentials fail the
release; unsigned downloads are never published.

Install the draft DMG, collect the six live client checks and background Focus
check against it, and run
`bun run test:compatibility -- --app=/Applications/Hush.app`. Publish only after
those checks pass on the exact signed download. These interactive checks need
signed-in clients and local permissions; hosted CI runs the compiled and real
WebKit/LaunchServices checks.

Signing certificates, the Communication Notifications profile and notarization
credentials live in Buddy-encrypted `.env.production`, alongside its public key.
GitHub Actions receives only `DOTENV_PRIVATE_KEY_PRODUCTION` and Pantry decrypts
through the shared Stacks environment API. `.env.keys` stays ignored. Manage
values with `./buddy env:set KEY --stdin --file .env.production`; validate with
`./buddy env:check --file .env.production --strict`. Pantry handles temporary
keychains, entitlement generation and credential cleanup.
Hush contains no signing, notarization or store-packaging scripts.

Mac App Store delivery is a separate Pantry target, enabled explicitly with
`native.macos.appStore: true` once distribution certificates, a store profile
and Connect credentials are configured. Its entitlement values are already
declared in `pantry.json`. Hush currently releases the Developer ID DMG.
See [Pantry native publishing](https://github.com/pantry-pm/pantry/tree/main/packages/ts-pantry#native-application-releases)
for account setup and provider configuration. Android delivery belongs to
Pantry too; Hush's application target is macOS.

### Why the two builds differ

They are not the same binary signed twice. The store requires the App Sandbox,
and the sandbox forbids spawning `/usr/bin/shortcuts` — the mechanism the
direct build uses to set Focus. Craft detects the sandbox and switches to
`shortcuts://run-shortcut`, which LaunchServices permits. The capability sets are
declared separately in `pantry.json` for the same reason.

The store also requires `CFBundleExecutable` to be a Mach-O image, so Craft is
the bundle's executable and reads `Resources/craft.json` beside it. There is no
launcher script. CI asserts this shape on every push.

### Known limitations under the sandbox

- Shortcuts cannot be enumerated, so Hush cannot verify the Focus shortcuts
  exist. It reports "unknown" and stays quiet rather than prompting someone who
  has already done the setup.
- Running a shortcut by URL is fire-and-forget: macOS confirms the request
  reached Shortcuts, never that the shortcut ran.
