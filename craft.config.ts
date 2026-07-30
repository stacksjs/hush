/**
 * Hush's native app manifest.
 *
 * Consumed by `scripts/build.ts`, which drives `stx build:native`. Keeping it
 * here rather than inline in the build script means the identifier, the
 * permission strings and the window shape are one file to review.
 */
export interface HushAppConfig {
  name: string
  bundleId: string
  category: string
  minimumSystemVersion: string
  window: { title: string, width: number, height: number }
  /** Extra Info.plist keys merged into the bundle. */
  infoPlist: Record<string, string | number | boolean>
}

export const config: HushAppConfig = {
  name: 'Hush',
  bundleId: 'org.stacksjs.hush',
  category: 'public.app-category.productivity',
  // Focus status via INFocusStatusCenter needs macOS 12; 13 is the oldest
  // release still receiving security updates, so there is no reason to claim
  // support below it.
  minimumSystemVersion: '13.0',

  window: {
    title: 'Hush',
    // Popover proportions — the window only ever appears attached to the
    // menubar item, so this is the popover size, not a document window.
    width: 340,
    height: 560,
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
}

export default config
