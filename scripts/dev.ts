#!/usr/bin/env bun
/**
 * Run Hush from source.
 *
 * Builds the bundle and launches it, so development exercises the same
 * pipeline that ships — a dev mode that renders the template a different way
 * is a dev mode that hides packaging bugs until release day.
 *
 * Set `CRAFT_BIN` to point at a local Craft build.
 */
import { spawn } from 'node:child_process'
import { dirname, join, resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

const build = spawn('bun', [join(root, 'scripts', 'build.ts'), '--verbose'], {
  cwd: root,
  stdio: 'inherit',
})

build.on('exit', (code) => {
  if (code !== 0) process.exit(code ?? 1)

  const launcher = join(root, 'dist', 'Hush.app', 'Contents', 'MacOS', 'Hush')
  // eslint-disable-next-line no-console
  console.log('\n▶ Launching Hush — look for the menubar icon. Ctrl-C to stop.\n')

  // Run the launcher in the foreground rather than `open`ing the bundle, so
  // Craft's stdout lands in this terminal and Ctrl-C stops the app.
  const app = spawn(launcher, [], { cwd: root, stdio: 'inherit' })
  app.on('exit', appCode => process.exit(appCode ?? 0))
})
