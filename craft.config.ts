/**
 * Hush's native app manifest.
 *
 * Buddy passes this configuration to the shared stx native packager.
 */
import type { NativeBuildConfig } from '@stacksjs/stx/craft'

export const config = {
  name: 'Hush',
  input: 'src/app.stx',
  target: 'macos',
  systemTray: true,
  trayPopover: true,
  icon: 'assets/hush.icns',
  bundleStyle: 'executable',
  bundleId: 'com.stacksjs.hush',
  category: 'public.app-category.productivity',
  // Focus status requires macOS 12; the packaged app targets macOS 13+.
  minimumSystemVersion: '13.0',

  window: {
    title: 'Hush',
    // Popover proportions — the window only ever appears attached to the
    // menubar item, so this is the popover size, not a document window.
    width: 368,
    height: 640,
    resizable: false,
  },

  infoPlist: {
    // Required for INFocusStatusCenter. Without this exact key the system
    // denies the authorization request with no error and `isFocused` stays
    // null forever.
    NSFocusStatusUsageDescription:
    'Hush checks whether a Focus is already on so it does not override one you set yourself.',
    NSHumanReadableCopyright: `Copyright © ${new Date().getFullYear()} Stacks.js. MIT licensed.`,
    // Menubar-only: no dock icon, no app switcher entry.
    LSUIElement: true,
  },

} satisfies NativeBuildConfig

export default config
