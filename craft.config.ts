/**
 * Hush's native app manifest.
 *
 * Buddy passes this configuration to the shared stx native packager.
 */
import type { NativeBuildConfig } from '@stacksjs/stx/craft'
import process from 'node:process'
import { join } from 'node:path'

const craftRevision = 'd420b7e01e19a9edb6c8bf2b0548677401859f62'
const appStore = process.env.HUSH_DISTRIBUTION === 'app-store'

/** Application metadata around stx's shared native build configuration. */
export type HushAppConfig = NativeBuildConfig & {
  craftVersion: string
  craftRevision: string
  entitlements: { direct: string, appStore: string }
}

export const config = {
  name: 'Hush',
  input: 'src/app.stx',
  target: 'macos',
  systemTray: true,
  trayPopover: true,
  icon: join(import.meta.dir, 'assets/hush.icns'),
  bundleStyle: 'executable',
  bundleId: 'org.stacksjs.hush',
  craftVersion: '0.0.295',
  craftRevision,
  craftPath: process.env.CRAFT_BIN || join(import.meta.dir, '.craft', craftRevision, 'Tools/craft/packages/zig/zig-out/bin/craft'),
  macosSigning: process.env.APPLE_PROVISIONING_PROFILE ? {
    identity: process.env.APPLE_SIGNING_IDENTITY,
    entitlements: join(import.meta.dir, appStore ? 'build/entitlements.appstore.plist' : 'build/entitlements.plist'),
    provisioningProfile: process.env.APPLE_PROVISIONING_PROFILE,
    hardenedRuntime: !appStore,
  } : undefined,
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

  entitlements: {
    direct: 'build/entitlements.plist',
    appStore: 'build/entitlements.appstore.plist',
  },
} satisfies HushAppConfig

export default config
