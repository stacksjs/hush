[Compare changes](https://github.com/stacksjs/hush/compare/v0.1.3...v0.2.0)

## 💥 Breaking Changes

- refactor!: remove the Swift/Xcode application ([e51064f](https://github.com/stacksjs/hush/commit/e51064f)) _(by Chris <chrisbreuer93@gmail.com>)_

## ✨ Features

- adopt native conference sharing detection fixes ([3c2509d](https://github.com/stacksjs/hush/commit/3c2509d)) _(by Chris <chrisbreuer93@gmail.com>)_
- adopt Dia sharing detection and record per-app native checks ([d1d933d](https://github.com/stacksjs/hush/commit/d1d933d)) _(by Chris <chrisbreuer93@gmail.com>)_
- expose native permission setup for shared browser tab detection ([f807ad7](https://github.com/stacksjs/hush/commit/f807ad7)) _(by Chris <chrisbreuer93@gmail.com>)_
- adopt the native Buddy workflow with a pinned minimal Craft runtime ([d845540](https://github.com/stacksjs/hush/commit/d845540)) _(by Chris <chrisbreuer93@gmail.com>)_
- ship an App Store-shaped bundle and handle Screen Recording ([517c3f3](https://github.com/stacksjs/hush/commit/517c3f3)) _(by Chris <chrisbreuer93@gmail.com>)_
- rebuild Hush on stx and Craft ([9cfccae](https://github.com/stacksjs/hush/commit/9cfccae)) _(by Chris <chrisbreuer93@gmail.com>)_

## 🐛 Bug Fixes

- pin native Slack detection and stage verified releases ([e7894a7](https://github.com/stacksjs/hush/commit/e7894a7)) _(by Chris <chrisbreuer93@gmail.com>)_
- keep native Focus transitions responsive in the background ([d0e6948](https://github.com/stacksjs/hush/commit/d0e6948)) _(by Chris <chrisbreuer93@gmail.com>)_
- distinguish idle Hush from the user’s active Focus ([f688ac5](https://github.com/stacksjs/hush/commit/f688ac5)) _(by Chris <chrisbreuer93@gmail.com>)_
- request native Screen Recording access before opening settings ([7e6a540](https://github.com/stacksjs/hush/commit/7e6a540)) _(by Chris <chrisbreuer93@gmail.com>)_
- require authorized Focus status before automatic activation ([5b65556](https://github.com/stacksjs/hush/commit/5b65556)) _(by Chris <chrisbreuer93@gmail.com>)_
- resume automatic Focus after shortcut setup completes ([3f0db79](https://github.com/stacksjs/hush/commit/3f0db79)) _(by Chris <chrisbreuer93@gmail.com>)_
- make native sharing transitions reliable and respect system Focus ([ff0e8ed](https://github.com/stacksjs/hush/commit/ff0e8ed)) _(by Chris <chrisbreuer93@gmail.com>)_
- **ci**: capture both streams when checking that the app launches ([2537ce9](https://github.com/stacksjs/hush/commit/2537ce9)) _(by Chris <chrisbreuer93@gmail.com>)_
- **ci**: source the pantry env instead of eval, and export CRAFT_BIN directly ([2168be7](https://github.com/stacksjs/hush/commit/2168be7)) _(by Chris <chrisbreuer93@gmail.com>)_

## 📝 Documentation

- describe the two release paths and why the store build differs ([e37cde3](https://github.com/stacksjs/hush/commit/e37cde3)) _(by Chris <chrisbreuer93@gmail.com>)_
- describe the stx + Craft architecture in the agent guide ([789b063](https://github.com/stacksjs/hush/commit/789b063)) _(by Chris <chrisbreuer93@gmail.com>)_
- rewrite the README for the stx + Craft app ([6559d99](https://github.com/stacksjs/hush/commit/6559d99)) _(by Chris <chrisbreuer93@gmail.com>)_

## ✅ Tests

- validate native tab sharing and signed artifact identity ([8c0e5f8](https://github.com/stacksjs/hush/commit/8c0e5f8)) _(by Chris <chrisbreuer93@gmail.com>)_
- require current artifacts for live client compatibility ([85c6358](https://github.com/stacksjs/hush/commit/85c6358)) _(by Chris <chrisbreuer93@gmail.com>)_
- verify native tab capture and record live sharing sources ([2c49f33](https://github.com/stacksjs/hush/commit/2c49f33)) _(by Chris <chrisbreuer93@gmail.com>)_
- drive the shipped bundle end to end ([ccd6328](https://github.com/stacksjs/hush/commit/ccd6328)) _(by Chris <chrisbreuer93@gmail.com>)_

## 👷 Build System

- verify native bundles and sign them with matching provisioning profiles ([aee7bf0](https://github.com/stacksjs/hush/commit/aee7bf0)) _(by Chris <chrisbreuer93@gmail.com>)_

## 💚 Continuous Integration

- build the Craft runtime from a pinned tag ([31d7fd8](https://github.com/stacksjs/hush/commit/31d7fd8)) _(by Chris <chrisbreuer93@gmail.com>)_
- build and release through the pantry action ([aef3046](https://github.com/stacksjs/hush/commit/aef3046)) _(by Chris <chrisbreuer93@gmail.com>)_

## 🔧 Chores

- release v0.2.0 ([34a74dc](https://github.com/stacksjs/hush/commit/34a74dc)) _(by Chris <chrisbreuer93@gmail.com>)_
- run @stacksjs/logsmith, not the unrelated npm 'logsmith' ([49050f3](https://github.com/stacksjs/hush/commit/49050f3)) _(by Chris <chrisbreuer93@gmail.com>)_
- release through @stacksjs/bumpx, not the unrelated npm 'bumpx' ([b33d5ef](https://github.com/stacksjs/hush/commit/b33d5ef)) _(by Chris <chrisbreuer93@gmail.com>)_
- **deps**: require stx and desktop 0.2.126 ([f3fb2fa](https://github.com/stacksjs/hush/commit/f3fb2fa)) _(by Chris <chrisbreuer93@gmail.com>)_
- ignore pantry directory ([e9d29b1](https://github.com/stacksjs/hush/commit/e9d29b1)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- **ci**: bump actions/checkout to v6, actions/cache to v5 ([eb445a7](https://github.com/stacksjs/hush/commit/eb445a7)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- refresh bun.lock and apply pickier --fix ([47fb5b6](https://github.com/stacksjs/hush/commit/47fb5b6)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- refresh bun.lock ([b02c5a5](https://github.com/stacksjs/hush/commit/b02c5a5)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- fix CI errors ([8ca2e2e](https://github.com/stacksjs/hush/commit/8ca2e2e)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- update vscode config ([d0de6e8](https://github.com/stacksjs/hush/commit/d0de6e8)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- update vscode config ([fd64971](https://github.com/stacksjs/hush/commit/fd64971)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- update dependencies ([ba42344](https://github.com/stacksjs/hush/commit/ba42344)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- add git-hooks config ([45260a2](https://github.com/stacksjs/hush/commit/45260a2)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- remove .zed and .cursor folders ([29a9fb6](https://github.com/stacksjs/hush/commit/29a9fb6)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- remove .pickierignore ([2036230](https://github.com/stacksjs/hush/commit/2036230)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- enrich CLAUDE.md with detailed project context from README ([ae25138](https://github.com/stacksjs/hush/commit/ae25138)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- update CLAUDE.md with project context and crosswind details ([4c4dda0](https://github.com/stacksjs/hush/commit/4c4dda0)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- add proper claude code guidelines ([7b4dbc9](https://github.com/stacksjs/hush/commit/7b4dbc9)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- ignore claude config in linter ([c3317b8](https://github.com/stacksjs/hush/commit/c3317b8)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- add claude code guidelines ([8e365ae](https://github.com/stacksjs/hush/commit/8e365ae)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- update CI action versions ([d0fee50](https://github.com/stacksjs/hush/commit/d0fee50)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- wip ([67d2113](https://github.com/stacksjs/hush/commit/67d2113)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- wip ([ab3a775](https://github.com/stacksjs/hush/commit/ab3a775)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- wip ([7098894](https://github.com/stacksjs/hush/commit/7098894)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- wip ([6482a94](https://github.com/stacksjs/hush/commit/6482a94)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- wip ([d130942](https://github.com/stacksjs/hush/commit/d130942)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- wip ([5f45b0f](https://github.com/stacksjs/hush/commit/5f45b0f)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- wip ([2d35759](https://github.com/stacksjs/hush/commit/2d35759)) _(by glennmichael123 <gtorregosa@gmail.com>)_
- wip ([ea19223](https://github.com/stacksjs/hush/commit/ea19223)) _(by glennmichael123 <gtorregosa@gmail.com>)_

## Contributors

- _Chris <chrisbreuer93@gmail.com>_
- _glennmichael123 <gtorregosa@gmail.com>_

## v0.1.2...main

[compare changes](https://github.com/stacksjs/hush/compare/v0.1.2...main)

### 🏡 Chore

- Adjust naming ([6c7b52e](https://github.com/stacksjs/hush/commit/6c7b52e))
- Lint ([4ee3bcd](https://github.com/stacksjs/hush/commit/4ee3bcd))
- Add bunfig ([8588634](https://github.com/stacksjs/hush/commit/8588634))

### ❤️ Contributors

- Chris ([@chrisbbreuer](https://github.com/chrisbbreuer))

## v0.1.1...main

[compare changes](https://github.com/stacksjs/hush/compare/v0.1.1...main)

### 🏡 Chore

- Install swiftlint ([8aef505](https://github.com/stacksjs/hush/commit/8aef505))

### ❤️ Contributors

- Chris ([@chrisbbreuer](https://github.com/chrisbbreuer))

## v0.1.0...main

[compare changes](https://github.com/stacksjs/hush/compare/v0.1.0...main)

### 🏡 Chore

- Wip ([e90fad3](https://github.com/stacksjs/hush/commit/e90fad3))
- Wip ([adcc80d](https://github.com/stacksjs/hush/commit/adcc80d))
- Wip ([9c184cc](https://github.com/stacksjs/hush/commit/9c184cc))
- Wip ([84e72b7](https://github.com/stacksjs/hush/commit/84e72b7))

### ❤️ Contributors

- Chris ([@chrisbbreuer](https://github.com/chrisbbreuer))

## ...main

### 🏡 Chore

- Initial commit ([2404239](https://github.com/stacksjs/hush/commit/2404239))
- Wip ([092fbe1](https://github.com/stacksjs/hush/commit/092fbe1))
- Wip ([cb3a1b0](https://github.com/stacksjs/hush/commit/cb3a1b0))
- Wip ([abf3b0e](https://github.com/stacksjs/hush/commit/abf3b0e))
- Wip ([8d7a857](https://github.com/stacksjs/hush/commit/8d7a857))
- Wip ([3666654](https://github.com/stacksjs/hush/commit/3666654))
- Wip ([ea9c2d3](https://github.com/stacksjs/hush/commit/ea9c2d3))
- Wip ([4a59db8](https://github.com/stacksjs/hush/commit/4a59db8))
- Wip ([26c49fe](https://github.com/stacksjs/hush/commit/26c49fe))
- Wip ([89a38e6](https://github.com/stacksjs/hush/commit/89a38e6))
- Wip ([d89be12](https://github.com/stacksjs/hush/commit/d89be12))
- Wip ([33606ec](https://github.com/stacksjs/hush/commit/33606ec))
- Wip ([adbcde9](https://github.com/stacksjs/hush/commit/adbcde9))
- Wip ([e73b00c](https://github.com/stacksjs/hush/commit/e73b00c))
- Wip ([68f6589](https://github.com/stacksjs/hush/commit/68f6589))
- Wip ([efcf031](https://github.com/stacksjs/hush/commit/efcf031))
- Wip ([92943fa](https://github.com/stacksjs/hush/commit/92943fa))
- Wip ([52fd245](https://github.com/stacksjs/hush/commit/52fd245))
- Wip ([2cf9878](https://github.com/stacksjs/hush/commit/2cf9878))
- Wip ([a330f30](https://github.com/stacksjs/hush/commit/a330f30))
- Wip ([cdcfdc0](https://github.com/stacksjs/hush/commit/cdcfdc0))
- Wip ([09ab2a6](https://github.com/stacksjs/hush/commit/09ab2a6))
- Wip ([9733d39](https://github.com/stacksjs/hush/commit/9733d39))
- Wip ([903f196](https://github.com/stacksjs/hush/commit/903f196))
- Wip ([5eea69e](https://github.com/stacksjs/hush/commit/5eea69e))
- Wip ([c50aaf5](https://github.com/stacksjs/hush/commit/c50aaf5))
- Wip ([932725b](https://github.com/stacksjs/hush/commit/932725b))
- Wip ([2c7a2c3](https://github.com/stacksjs/hush/commit/2c7a2c3))
- Wip ([896d0d7](https://github.com/stacksjs/hush/commit/896d0d7))
- Wip ([a7e54a5](https://github.com/stacksjs/hush/commit/a7e54a5))
- Wip ([7f83dec](https://github.com/stacksjs/hush/commit/7f83dec))

### ❤️ Contributors

- Chris ([@chrisbbreuer](https://github.com/chrisbbreuer))
