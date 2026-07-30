#!/usr/bin/env bun
/**
 * Build Hush into a distributable macOS app.
 *
 * Everything native comes from our own tools: stx compiles `src/app.stx` and
 * bundles the client, and Craft is the runtime copied into the bundle. There
 * is no Xcode, no Swift and no third-party packager in the path.
 *
 *   bun run build            → dist/Hush.app
 *   bun run package          → dist/Hush.app + dist/Hush-<version>.dmg
 */
import { existsSync, rmSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { buildNative } from '@stacksjs/stx/craft'
import { config } from '../craft.config'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

async function main(): Promise<void> {
  const pkg = await Bun.file(join(root, 'package.json')).json()
  const wantsDmg = process.argv.includes('--dmg')
  const outputDir = join(root, 'dist')

  // A stale bundle is worse than no bundle: a rename or a removed resource
  // leaves a working-looking .app assembled from two different builds.
  if (existsSync(outputDir))
    rmSync(outputDir, { recursive: true, force: true })

  const iconPath = join(root, 'build', 'AppIcon.icns')

  const result = await buildNative({
    input: join(root, 'src', 'app.stx'),
    output: outputDir,
    target: 'macos',
    format: wantsDmg ? 'dmg' : 'app',
    name: config.name,
    version: pkg.version,
    description: pkg.description,
    author: pkg.author,
    bundleId: config.bundleId,
    icon: existsSync(iconPath) ? iconPath : undefined,
    window: config.window,
    systemTray: true,
    menubarOnly: true,
    category: config.category,
    minimumSystemVersion: config.minimumSystemVersion,
    infoPlist: config.infoPlist,
    verbose: process.argv.includes('--verbose'),
  })

  if (!result.success) {
    // eslint-disable-next-line no-console
    console.error(`✖ Build failed: ${result.error}`)
    process.exit(1)
  }

  // eslint-disable-next-line no-console
  console.log(`✔ ${config.name} ${pkg.version} → ${result.outputPath}`)
}

main().catch((error) => {
  // eslint-disable-next-line no-console
  console.error(error)
  process.exit(1)
})
