#!/usr/bin/env bun
/** Exercise the shipped client inside real WebKit and the real Craft bridge. */
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { config } from '../craft.config'

if (process.platform !== 'darwin') throw new Error('Native verification requires macOS.')
const root = resolve(import.meta.dir, '..')
const bundle = resolve(process.argv.find(arg => arg.startsWith('--app='))?.slice(6) ?? join(root, 'dist/Hush.app'))
const executable = join(bundle, 'Contents/MacOS/Hush')
const html = readFileSync(join(bundle, 'Contents/Resources/index.html'), 'utf8')
function bundleSize(path: string): number {
  const stat = statSync(path)
  return stat.isDirectory() ? readdirSync(path).reduce((total, name) => total + bundleSize(join(path, name)), 0) : stat.size
}
const bundleBytes = bundleSize(bundle)
if (bundleBytes > 4 * 1024 * 1024) throw new Error(`Native bundle exceeds the 4 MiB budget: ${bundleBytes} bytes. Build the minimal WebKit runtime.`)
const signature = Bun.spawnSync(['codesign', '-dv', bundle]).stderr.toString()
if (!signature.includes(`Identifier=${config.bundleId}\n`) || signature.includes('Info.plist=not bound'))
  throw new Error('The native signature must bind Hush’s identity and Info.plist.')
if (Bun.spawnSync(['codesign', '--verify', '--strict', bundle]).exitCode !== 0)
  throw new Error('The native bundle signature is invalid.')
const loadCommands = Bun.spawnSync(['otool', '-l', executable])
if (loadCommands.exitCode !== 0) throw new Error('Could not inspect the native macOS deployment target.')
const minimum = loadCommands.stdout.toString().match(/\bminos\s+([\d.]+)/)?.[1]
if (!minimum) throw new Error('The native executable has no macOS deployment target.')
const versionNumber = (version: string) => version.split('.').reduce((total, part, index) => total + Number(part) / 1000 ** index, 0)
if (versionNumber(minimum) > versionNumber(config.minimumSystemVersion))
  throw new Error(`Runtime requires macOS ${minimum}, while Hush declares ${config.minimumSystemVersion}.`)
const sourceAudit = Bun.spawnSync(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '*.swift', '*.kt', '*.kts'], { cwd: root })
if (sourceAudit.exitCode !== 0 || sourceAudit.stdout.toString().trim()) throw new Error('Hush application source must contain no Swift or Kotlin.')
const work = mkdtempSync(join(tmpdir(), 'hush-native-check-'))
const reportPath = join(work, 'result.json')
const nativeFile = join(work, 'native-file.txt')
const setupPermissions = process.argv.includes('--setup-permissions')
const exerciseFocus = process.argv.includes('--exercise-focus')
const observeSharing = exerciseFocus || process.argv.includes('--observe-sharing')
const launchServices = setupPermissions || observeSharing || process.argv.includes('--launch-services')

// Run the compiled application unchanged, followed by assertions. No bridge
// mocks, permissions changes, or Focus changes are involved in this check.
const assertions = `<script>
(async function() {
  const deadline = Date.now() + 15000;
  while (document.getElementById('app').dataset.ready !== 'true') {
    if (Date.now() > deadline) throw new Error('Controller did not start: ' + document.getElementById('status').textContent);
    await new Promise(r => setTimeout(r, 100));
  }
  await craft.fs.writeFile(${JSON.stringify(nativeFile)}, 'Hush native round trip');
  async function stage(name) {
    await craft.fs.writeFile(${JSON.stringify(reportPath)}, JSON.stringify({ error: 'Native check did not complete: ' + name }));
  }
  await stage('filesystem read');
  const contents = await craft.fs.readFile(${JSON.stringify(nativeFile)});
  if (contents.data !== 'Hush native round trip') throw new Error('Native filesystem round trip failed');
  await stage('sharing state');
  const [state, concurrentState] = await Promise.all([craft.screenSharing.getState(), craft.screenSharing.getState()]);
  if (typeof state.sharing !== 'boolean' || !Array.isArray(state.sources)) throw new Error('Invalid native sharing state');
  if (typeof concurrentState.sharing !== 'boolean') throw new Error('Concurrent native sharing requests lost their response');
  await stage('shortcut enumeration');
  const shortcuts = await craft.focus.listShortcutsResult();
  const missingShortcut = ${JSON.stringify(`Hush native missing ${work.split('/').pop()}`)};
  if (shortcuts.shortcuts.includes(missingShortcut)) throw new Error('Native check requires an absent test shortcut');
  await stage('shortcut failure');
  const failure = craft.focus.runShortcut(missingShortcut);
  const responsiveAt = Date.now();
  await craft.fs.readFile(${JSON.stringify(nativeFile)});
  if (Date.now() - responsiveAt > 5000) throw new Error('A Shortcut blocked the native UI thread');
  if ((await failure).ok !== false) throw new Error('Native Shortcut failure was reported as success');
  ${setupPermissions ? 'await craft.notifications.requestPermission(); await craft.focus.requestAuthorization();' : ''}
  await stage('Focus status');
  const focusStatus = await craft.focus.getStatus();
  const screenRecording = await craft.permissions.check('screen_recording');
  const accessibility = await craft.permissions.check('accessibility');
  if (screenRecording !== 'granted' && screenRecording !== 'denied') throw new Error('Screen Recording must use the real macOS permission API');
  let liveSharingVerified = false;
  await stage('live sharing');
  ${observeSharing ? `
  if (screenRecording !== 'granted' || focusStatus.authorization !== 'authorized' || focusStatus.isFocused !== ${!exerciseFocus})
    throw new Error('Live check requires granted permissions and ${exerciseFocus ? 'no active' : 'an existing user'} Focus');
  async function waitForSharing(expected) {
    const deadline = Date.now() + 120000;
    while (document.getElementById('app').dataset.sharing !== String(expected)) {
      if (Date.now() > deadline) throw new Error('The native sharing transition did not reach the shipped client');
      await new Promise(r => setTimeout(r, 250));
    }
  }
  await waitForSharing(true);
  ${exerciseFocus ? `
  const activationDeadline = Date.now() + 30000;
  while (document.getElementById('app').dataset.engaged !== 'true') {
    if (Date.now() > activationDeadline) throw new Error('Hush did not enable Focus: ' + document.getElementById('status').textContent);
    await new Promise(r => setTimeout(r, 250));
  }
  if ((await craft.focus.getStatus()).isFocused !== true) throw new Error('Automatic activation did not reach macOS');
  ` : `if (document.getElementById('app').dataset.engaged !== 'false') throw new Error('Hush replaced the existing Focus');`}
  await craft.fs.writeFile(${JSON.stringify(join(root, 'dist/live-sharing-start.json'))}, JSON.stringify(await craft.screenSharing.getState()));
  await waitForSharing(false);
  ${exerciseFocus ? `
  const releaseDeadline = Date.now() + 30000;
  while (document.getElementById('app').dataset.engaged !== 'false') {
    if (Date.now() > releaseDeadline) throw new Error('Hush did not release Focus');
    await new Promise(r => setTimeout(r, 250));
  }
  ` : ''}
  if ((await craft.focus.getStatus()).isFocused !== ${!exerciseFocus}) throw new Error('Unexpected macOS Focus after sharing');
  liveSharingVerified = true;
  ` : ''}
  if (typeof shortcuts.canList !== 'boolean') throw new Error('Invalid native shortcut response');
  await craft.fs.writeFile(${JSON.stringify(reportPath)}, JSON.stringify({ ready: true, sharing: state.sharing, screenRecording, accessibility, canListShortcuts: shortcuts.canList, focusAuthorization: focusStatus.authorization, isFocused: focusStatus.isFocused, liveSharingVerified, focusShortcutsInstalled: shortcuts.shortcuts.includes('Hush Focus On') && shortcuts.shortcuts.includes('Hush Focus Off') }));
  document.getElementById('quit').click();
})().catch(async function(error) {
  try {
    await craft.fs.writeFile(${JSON.stringify(reportPath)}, JSON.stringify({ error: error instanceof Error ? error.message : JSON.stringify(error) }));
  }
  finally { document.getElementById('quit').click(); }
});
</script>`

try {
  const input = join(work, 'index.html')
  writeFileSync(input, html.replace('</body>', `${assertions}</body>`))
  const started = performance.now()
  const args = launchServices
    ? ['open', '-W', '-n', bundle, '--args', '--html-file', input]
    : [executable, '--html-file', input]
  const child = Bun.spawn(args, { stdout: 'pipe', stderr: 'pipe' })
  const timeout = setTimeout(() => child.kill(), observeSharing ? 250_000 : setupPermissions ? 120_000 : 25_000)
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited,
  ]).finally(() => clearTimeout(timeout))
  if (exitCode !== 0) throw new Error(`Native app exited with ${exitCode}: ${stdout}${stderr}`)
  const report = JSON.parse(readFileSync(reportPath, 'utf8'))
  if (report.error || report.ready !== true) throw new Error(`${report.error ?? 'Native app was not ready'}\n${stderr}`)
  report.minimumMacOS = minimum
  report.bundleBytes = bundleBytes
  report.nativeCheckMs = Math.round(performance.now() - started)
  report.launchServices = launchServices
  report.automaticFocusVerified = exerciseFocus
  writeFileSync(join(root, observeSharing ? exerciseFocus ? 'dist/live-focus-check.json' : 'dist/live-native-check.json' : launchServices ? 'dist/native-app-check.json' : 'dist/native-check.json'), `${JSON.stringify(report, null, 2)}\n`)
  // eslint-disable-next-line no-console
  console.log('Native WebKit startup, filesystem, detection, shortcut enumeration and clean shutdown verified.')
}
finally {
  rmSync(work, { recursive: true, force: true })
}
