# Claude Code Guidelines

## About

Hush is a macOS menubar app that detects screen sharing and turns Focus on while you present. It is a Stacks app: stx compiles the UI, Craft is the native runtime, Bun runs the build. Application source is STX and TypeScript, with no Xcode project, Swift, Kotlin, or third-party packager. Runtime builds use Zig and the macOS SDK.

Layout:

- `src/core/` — platform-free. The decision engine, preferences and statistics. No imports outside itself, which is what makes it testable without a window or a Mac.
- `src/runtime/` — the controller wiring detection → policy → Focus, plus storage through Craft's file bridge.
- `src/client/` — binds the controller to the popover DOM.
- `src/app.stx` — the UI. `<script server>` for build-time data, `<script client>` for the entry import.
- `scripts/` — application-specific native verification. Buddy owns build/dev/package; Pantry provisions Craft.

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

- `bun run release:patch` / `release:minor` / `release:major` — Buddy delegates qualification and versioning to Pantry, then the shared publisher commits, tags and pushes
- The tag calls Pantry's versioned native app workflow; `pantry.json` declares runtime pins, capabilities, checks and release targets
- Pantry owns runtime/toolchain setup, signing, notarization, store packaging and publishing. Keep scripts and provider logic in `~/Code/pantry`
- Release credentials are Buddy-encrypted in `.env.production`; only `DOTENV_PRIVATE_KEY_PRODUCTION` is passed to Actions. Keep `.env.keys` ignored; Pantry decrypts through `@stacksjs/env`
- The configured Developer ID target requires signing and notarization; missing credentials fail the release. A draft is published only after exact-artifact live compatibility verification
- Mac App Store delivery is opt-in through Pantry after account credentials are configured; Hush currently distributes a notarized DMG

## Bundle shape

- Craft is `CFBundleExecutable` and reads `Contents/Resources/craft.json`. There is **no launcher script** — the Mac App Store requires a Mach-O executable, and CI asserts it
- The Craft runtime is built from source at the immutable commit in `pantry.json.native.runtime` (revision and version checked), with the upstream first-party dependency SHAs and Zig lock respected. Bumping Craft means bumping that one field
- The store build is sandboxed, which changes behaviour rather than just packaging: Focus is set through `shortcuts://run-shortcut` instead of the CLI, and shortcuts cannot be enumerated, so `shortcutsReady` can be `'unknown'`
