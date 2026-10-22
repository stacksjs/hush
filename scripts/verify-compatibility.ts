#!/usr/bin/env bun
/** Validate completed live client checks against the current native artifact. */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { config } from '../craft.config'
import { nativeArtifactSha256 } from './native-artifact'

const root = resolve(import.meta.dir, '..')
const bundle = resolve(process.argv.find(arg => arg.startsWith('--app='))?.slice(6) ?? join(root, 'dist/Hush.app'))
mkdirSync(join(root, 'dist/e2e'), { recursive: true })
writeFileSync(join(root, 'dist/e2e/compatibility.json'), `${JSON.stringify({ status: 'running', checkedAt: new Date().toISOString() }, null, 2)}\n`)
if (Bun.spawnSync(['codesign', '--verify', '--strict', bundle]).exitCode !== 0)
  throw new Error('The current native artifact has an invalid signature or modified resources.')
const executableSha256 = new Bun.CryptoHasher('sha256').update(readFileSync(join(bundle, 'Contents/MacOS/Hush'))).digest('hex')
const artifactSha256 = nativeArtifactSha256(bundle)
const cases = [
  ['zoom-window', 'Zoom'],
  ['teams-window', 'Microsoft Teams'],
  ['dia-local-tab', 'Dia'],
  ['discord-window', 'Discord'],
  ['slack-window', 'Slack'],
  ['google-meet-dia', 'Dia'],
  ['zoom-automatic-focus-background', 'Zoom'],
] as const
const failures: string[] = []
const results = cases.map(([name, app]) => {
  const path = join(root, 'dist/e2e', `${name}.json`)
  if (!existsSync(path)) {
    failures.push(`${name}: missing live report`)
    return { name, app, status: 'missing' }
  }
  let report
  try {
    report = JSON.parse(readFileSync(path, 'utf8'))
    if (!report || typeof report !== 'object') throw new Error('Invalid report')
  }
  catch {
    failures.push(`${name}: invalid live report`)
    return { name, app, status: 'failed' }
  }
  const errors: string[] = []
  if (report.status !== 'passed' || report.liveSharingVerified !== true || report.sharing !== false)
    errors.push('requires a completed idle/start/stop cycle')
  if (report.artifactSha256 !== artifactSha256 || report.executableSha256 !== executableSha256 || report.configuredCraftRevision !== config.craftRevision)
    errors.push('report belongs to another build')
  if (name === 'zoom-automatic-focus-background') {
    if (report.automaticFocusVerified !== true || report.isFocused !== false || !Number.isFinite(report.initialIdleMs) || report.initialIdleMs < 60_000)
      errors.push('automatic Focus activation/release after a minute in the background was not verified')
  }
  else if (report.focusPreservationVerified !== true || report.focusPreservationSettled !== true || report.isFocused !== true) {
    errors.push('existing Focus preservation was not verified')
  }
  if (report.screenRecording !== 'granted' || report.accessibility !== 'granted' || report.focusAuthorization !== 'authorized')
    errors.push('required native permissions were absent')
  if (!Array.isArray(report.liveSharingSources) || !report.liveSharingSources.some((source: { app: string }) => source?.app === app))
    errors.push(`missing native ${app} source`)
  if (app === 'Dia' && report.tabSharingVerified !== true)
    errors.push('native tab sharing was not verified')
  if (errors.length) failures.push(`${name}: ${errors.join('; ')}`)
  return { name, app, status: errors.length ? 'failed' : 'passed', checkedAt: report.checkedAt, sources: report.liveSharingSources }
})
const summary = { status: failures.length ? 'failed' : 'passed', artifactSha256, executableSha256, configuredCraftRevision: config.craftRevision, checkedAt: new Date().toISOString(), cases: results, failures }
writeFileSync(join(root, 'dist/e2e/compatibility.json'), `${JSON.stringify(summary, null, 2)}\n`)
if (failures.length) throw new Error(failures.join('\n'))
// eslint-disable-next-line no-console
console.log('All six clients and background Focus activation/release passed on the current native executable.')
