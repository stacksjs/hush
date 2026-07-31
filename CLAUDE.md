# Claude Code Guidelines

## About

Hush is a macOS menubar app that detects screen sharing and turns Focus on while you present. It is a Stacks app: stx compiles the UI, Craft is the native runtime, Bun runs the build. There is no Xcode, Swift or third-party packager anywhere in the pipeline.

Layout:

- `src/core/` — platform-free. The decision engine, preferences and statistics. No imports outside itself, which is what makes it testable without a window or a Mac.
- `src/runtime/` — the controller wiring detection → policy → Focus, plus storage through Craft's file bridge.
- `src/client/` — binds the controller to the popover DOM.
- `src/app.stx` — the UI. `<script server>` for build-time data, `<script client>` for the entry import.
- `scripts/` — the build and dev drivers.

Two constraints shape the whole app, and neither is negotiable:

- **macOS will not let a third-party app set Focus.** `donotdisturbd` rejects any client without `com.apple.private.donotdisturb.mode.assertion.client-identifiers`, which only Apple's own apps hold. Focus is changed by running a user-created Shortcut. Reading Focus *is* public API (`INFocusStatusCenter`), but needs `NSFocusStatusUsageDescription` in the bundle.
- **Detection must match sharing indicators, not running apps.** "Zoom is open" describes most of a working day. Anything that keys off a bundle identifier or frontmost app will silence notifications permanently.

Native capabilities live in Craft (`~/Code/Tools/craft`) and are surfaced through `@stacksjs/desktop`. Add them there, not here — Hush should stay the app, not the platform.

## Linting

- Use **pickier** for linting — never use eslint directly
- Run `bunx --bun pickier .` to lint, `bunx --bun pickier . --fix` to auto-fix
- When fixing unused variable warnings, prefer `// eslint-disable-next-line` comments over prefixing with `_`

## Frontend

- Use **stx** for templating — never write vanilla JS (`var`, `document.*`, `window.*`) in stx templates
- Use **crosswind** as the default CSS framework which enables standard Tailwind-like utility classes
- stx `<script>` tags should only contain stx-compatible code (signals, composables, directives)
- `<script server>` is what populates the template context; a bare `<script>` is bundled as a client script
- Import `@stacksjs/desktop/browser`, never the package root — the root entry carries host-side modules that pull in `node:child_process` and cannot be bundled for a webview

## Dependencies

- **buddy-bot** handles dependency updates — not renovatebot
- **better-dx** provides shared dev tooling as peer dependencies — do not install its peers (e.g., `typescript`, `pickier`, `bun-plugin-dtsx`) separately if `better-dx` is already in `package.json`
- If `better-dx` is in `package.json`, ensure `bunfig.toml` includes `linker = "hoisted"`

## Commits

- Use conventional commit messages (e.g., `fix:`, `feat:`, `chore:`)

## Releasing

- `bun run release:patch` / `release:minor` / `release:major` — bumpx bumps, commits, tags and pushes
- The tag triggers `.github/workflows/release.yml`, which builds once and produces two artifacts: a notarized DMG published as a GitHub release through the **pantry** action, and a sandboxed `.pkg` uploaded to App Store Connect
- Release notes come from the commits since the previous tag (`release-changelog: auto`), so conventional messages are what the release page reads
- Both signing paths are conditional on their secrets; without them the release still completes as an unsigned direct download

## Bundle shape

- Craft is `CFBundleExecutable` and reads `Contents/Resources/craft.json`. There is **no launcher script** — the Mac App Store requires a Mach-O executable, and CI asserts it
- The Craft runtime is built from source at the tag in `craft.config.ts` (`craftVersion`), because Actions is disabled for the home-lang org and the published craft is stuck at 0.0.37. Bumping Craft means bumping that one field
- The store build is sandboxed, which changes behaviour rather than just packaging: Focus is set through `shortcuts://run-shortcut` instead of the CLI, and shortcuts cannot be enumerated, so `shortcutsReady` can be `'unknown'`
