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

bumpx bumps the version, commits, tags and pushes. The tag triggers the
release workflow, which builds the app, signs and notarizes it when the Apple
secrets are configured, and publishes a GitHub release through the pantry
action with generated notes, a checksums manifest and the DMG attached.

## Privacy

Hush only detects screen sharing state locally on your Mac and doesn't collect or transmit any data.

## Changelog

Please see our [CHANGELOG.md](CHANGELOG.md) for more information on what has changed recently.

## Contributing

Please see the [Contributing Guide](.github/CONTRIBUTING.md) for details.

## Community

For help, discussion about best practices, or any other conversation that would benefit from being searchable:

[Discussions on GitHub](https://github.com/username/hush/discussions)

## Postcardware

"Software that is free, but hopes for a postcard." We love receiving postcards from around the world showing where Stacks is being used! We showcase them on our website too.

Our address: Stacks.js, 12665 Village Ln #2306, Playa Vista, CA 90094, United States 🌎

## Sponsors

We would like to extend our thanks to the following sponsors for funding Stacks development. If you are interested in becoming a sponsor, please reach out to us.

- [JetBrains](https://www.jetbrains.com/)
- [The Solana Foundation](https://solana.com/)

## Credits

- [Muzzle](https://github.com/gilbarbara/muzzle) - Thanks for the inspiration!
- [Chris Breuer](https://github.com/chrisbbreuer)
- [All Contributors](../../contributors)

## License

The MIT License (MIT). Please see [LICENSE](LICENSE.md) for more information.

Made with 💙
