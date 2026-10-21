#!/usr/bin/env bun
/** Provision the exact upstream runtime and its pinned first-party toolchain. */
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { config } from '../craft.config'

const root = resolve(import.meta.dir, '..')
const workspace = join(root, '.craft', config.craftRevision)
const checkout = join(workspace, 'Tools', 'craft')
const binary = join(checkout, 'packages/zig/zig-out/bin/craft')
const profile = join(checkout, '.hush-runtime-profile')
const architecture = process.arch === 'arm64' ? 'aarch64' : process.arch === 'x64' ? 'x86_64' : null
if (process.platform !== 'darwin' || !architecture) throw new Error('Hush runtime builds require an arm64 or x64 Mac.')
const target = `${architecture}-macos.${config.minimumSystemVersion}`
const runtimeProfile = `ReleaseSmall;js-runtime=false;target=${target}`

async function command(args: string[], cwd: string, env = process.env): Promise<void> {
  const proc = Bun.spawn(args, { cwd, env, stdin: 'ignore', stdout: 'inherit', stderr: 'inherit' })
  if (await proc.exited !== 0) throw new Error(`Runtime setup failed: ${args.join(' ')}`)
}

async function clone(repository: string, revision: string, destination: string): Promise<void> {
  if (existsSync(join(destination, '.git'))) {
    const current = Bun.spawnSync(['git', 'rev-parse', 'HEAD'], { cwd: destination }).stdout.toString().trim()
    if (current !== revision) throw new Error(`Unexpected source revision in ${destination}: ${current}`)
    return
  }
  mkdirSync(destination, { recursive: true })
  await command(['git', 'init', '--quiet'], destination)
  await command(['git', 'remote', 'add', 'origin', `https://github.com/${repository}.git`], destination)
  await command(['git', 'fetch', '--quiet', '--depth', '1', 'origin', revision], destination)
  await command(['git', 'checkout', '--quiet', '--detach', 'FETCH_HEAD'], destination)
}

if (!existsSync(binary) || !existsSync(profile) || readFileSync(profile, 'utf8') !== runtimeProfile) {
  await clone('craft-native/craft', config.craftRevision, checkout)
  const pins = readFileSync(join(checkout, '.github/actions/first-party-zig-deps/pins.env'), 'utf8')
  for (const [name, key] of [['zig-js', 'zig_js'], ['zig-regex', 'zig_regex'], ['zig-gc', 'zig_gc']]) {
    const revision = pins.match(new RegExp(`^${key}=([a-f0-9]{40})$`, 'm'))?.[1]
    if (!revision) throw new Error(`Missing upstream dependency pin: ${key}`)
    await clone(`zig-utils/${name}`, revision, join(workspace, 'Libraries', name!))
  }
  const lock = JSON.parse(readFileSync(join(checkout, 'pantry.lock'), 'utf8'))
  const version: string = lock.workspaces[''].system['ziglang.org']
  await command(['pantry', 'install', `ziglang.org@${version}`, '--no-save', '--ignore-scripts'], checkout)
  const zig = join(checkout, 'pantry/ziglang.org', `v${version}`, 'bin/zig')
  if (!existsSync(zig)) throw new Error(`The pinned Pantry Zig compiler is missing: ${zig}`)
  const sdkResult = Bun.spawnSync(['xcrun', '--sdk', 'macosx', '--show-sdk-path'])
  const sdk = sdkResult.stdout.toString().trim()
  if (sdkResult.exitCode !== 0 || !sdk) throw new Error('The macOS SDK is required to build the pinned deployment target.')
  await command(['bun', 'scripts/zig.ts', '--core', '--versioned', 'build', '-Doptimize=ReleaseSmall', '-Djs-runtime=false', `-Dtarget=${target}`, `-Dmacos-sdk=${sdk}`], checkout, { ...process.env, CRAFT_ZIG: zig })
  writeFileSync(profile, runtimeProfile)
}

const runtime = Bun.spawnSync([binary, '--version'], { stdout: 'pipe', stderr: 'pipe' })
if (runtime.exitCode !== 0 || !`${runtime.stdout}${runtime.stderr}`.includes(`craft version ${config.craftVersion}`))
  throw new Error(`Craft does not match the pinned version ${config.craftVersion}`)
if (process.env.GITHUB_ENV) appendFileSync(process.env.GITHUB_ENV, `CRAFT_BIN=${binary}\n`)
// eslint-disable-next-line no-console
console.log(binary)
