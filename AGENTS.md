# Hush

Hush is a Buddy-managed macOS status-item app. Application source is STX and
TypeScript. Do not add Swift or Kotlin to this repository. Keep platform code
and reusable native features behind Craft and `@stacksjs/desktop`; extend stx
components at their source instead of implementing platform workarounds here.

Source checkouts:

- Stacks/Buddy: `~/Code/stacks`
- stx and desktop APIs: `~/Code/Libraries/stx`
- Craft: `~/Code/Tools/craft`

Fix those sources, test them, and consume their published packages. Bun package
linking and `CRAFT_BIN` are the supported local development overrides. Never
patch installed dependencies. Hush keeps its policy, preferences, statistics,
and UI; Buddy owns development, compilation, and packaging.

`craft.config.ts` selects `trayPopover: true`. Craft's `menubarOnly` mode creates
no page. The runtime is pinned by immutable Git revision and built using its
locked Zig compiler, upstream dependency pins, `ReleaseSmall`, and
`-Djs-runtime=false`, targeting the declared minimum macOS version. That last option removes Craft's CLI interpreter, while
the application runs on system WebKit. Keep the distributable below 4 MiB.

Use pickier for lint and formatting. Validate changes with:

```sh
bun install --frozen-lockfile
bun run verify
bun run package
```

`test:unit` covers platform-free policy and controller behavior. `test:e2e`
requires an actual built artifact and must fail if it is missing. `test:native`
runs that client in real WebKit against Craft, checks the binary-size and
source-language constraints, and requires a clean exit. `test:native:app` also
checks the app through LaunchServices. CI runs compiled and both native checks. Never replace the native check with mocks or skip failed checks.

macOS requires Screen Recording permission for window titles. Focus control
uses the user's two Focus shortcuts. Never claim a live Focus transition was
verified when those shortcuts or permissions are absent. Automatic activation
must first read Focus status and leave a pre-existing Focus alone. Explicit
`--observe-sharing` and `--exercise-focus` native checks cover live preservation
and automatic activation/release. Chrome and Dia tab-only capture, Discord, and Slack use Craft’s public
Accessibility reader and require its separate user grant. Never substitute a fake window title for a live test.

Use conventional commits and the repository's configured human Git identity.
Push completed changes normally to `origin/main`, with no coauthor trailers.
Preserve unrelated work and never force-push.
