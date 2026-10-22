#!/usr/bin/env bun
/** Exercise the shipped client inside real WebKit and the real Craft bridge. */
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { config } from '../craft.config'
import { nativeArtifactSha256 } from './native-artifact'
import { isNativeTabSharing } from './native-sharing'

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
const expectTabSharing = process.argv.includes('--expect-tab-sharing')
const expectedApp = process.argv.find(arg => arg.startsWith('--expect-app='))?.slice(13)
const expectedSource = process.argv.find(arg => arg.startsWith('--expect-source='))?.slice(16)
const testCase = process.argv.find(arg => arg.startsWith('--case='))?.slice(7)
if (testCase && !/^[a-z0-9][a-z0-9-]{0,63}$/.test(testCase)) throw new Error('Use a lowercase, hyphenated test case name.')
const observeSharing = exerciseFocus || expectTabSharing || Boolean(expectedApp) || process.argv.includes('--observe-sharing')
const backgroundArgument = process.argv.find(arg => arg.startsWith('--background-ms='))?.slice(16)
const backgroundMs = backgroundArgument ? Number(backgroundArgument) : 0
if (!Number.isSafeInteger(backgroundMs) || backgroundMs < 0 || backgroundMs > 120_000) throw new Error('Background duration must be 0–120000 milliseconds.')
if (backgroundMs && observeSharing) throw new Error('Run background timing and interactive sharing checks separately.')
const launchServices = setupPermissions || observeSharing || backgroundMs > 0 || process.argv.includes('--launch-services')
const timeoutArgument = process.argv.find(arg => arg.startsWith('--timeout-ms='))?.slice(13)
const budget = timeoutArgument ? Number(timeoutArgument) : observeSharing ? 250_000 : setupPermissions ? 120_000 : 25_000 + backgroundMs
if (!Number.isSafeInteger(budget) || budget < 1000 || budget > 600_000) throw new Error('Native timeout must be 1000–600000 milliseconds.')
const output = testCase
  ? join(root, 'dist/e2e', `${testCase}.json`)
  : join(root, observeSharing ? exerciseFocus ? 'dist/live-focus-check.json' : 'dist/live-native-check.json' : launchServices ? 'dist/native-app-check.json' : 'dist/native-check.json')
if (testCase) mkdirSync(join(root, 'dist/e2e'), { recursive: true })
const runMetadata = { testCase: testCase ?? null, expectedApp: expectedApp ?? null, configuredCraftRevision: config.craftRevision, artifactSha256: nativeArtifactSha256(bundle), executableSha256: new Bun.CryptoHasher('sha256').update(readFileSync(executable)).digest('hex'), checkedAt: new Date().toISOString() }
writeFileSync(output, `${JSON.stringify({ ...runMetadata, status: 'running' }, null, 2)}\n`)

// Run the compiled application unchanged, followed by assertions. No bridge
// mocks, permissions changes, or Focus changes are involved in this check.
const assertions = `<script>
(async function() {
  const nativeSharingEvents = [];
  window.addEventListener('craft:screenSharing:change', event => {
    nativeSharingEvents.push({ at: Date.now(), state: event.detail });
    if (nativeSharingEvents.length > 20) nativeSharingEvents.shift();
  });
  const deadline = Date.now() + 15000;
  while (document.getElementById('app').dataset.ready !== 'true') {
    if (Date.now() > deadline) throw new Error('Controller did not start: ' + document.getElementById('status').textContent);
    await new Promise(r => setTimeout(r, 100));
  }
  const controls = ['toggle-focus', 'pref-automatic', 'pref-keep', 'pref-notify', 'pref-login'];
  for (const id of controls) {
    const input = document.getElementById(id);
    if (!(input instanceof HTMLInputElement) || input.type !== 'checkbox' || input.getAttribute('role') !== 'switch' || !input.hasAttribute('switch'))
      throw new Error('The shipped native switch did not render: ' + id);
    if (!document.querySelector('label[for="' + id + '"]')) throw new Error('Native switch has no label: ' + id);
  }
  if (!document.querySelector('.brand svg path')) throw new Error('Hush logo did not render');
  const nativeTray = await craft.tray.getState();
  if (nativeTray.title !== '' || nativeTray.tooltip !== 'Hush — a little peace of mind' || !nativeTray.hasIcon || !nativeTray.template || !nativeTray.visible || nativeTray.imagePosition !== 1)
    throw new Error('Hush status item did not render its icon and title correctly: ' + JSON.stringify(nativeTray));
  const nativeLoginEnabled = await craft.autoLaunch.isEnabled();
  if (document.getElementById('pref-login').checked !== nativeLoginEnabled) throw new Error('Launch at login disagrees with macOS');
  if (document.documentElement.scrollWidth > innerWidth) throw new Error('Popover content overflows horizontally');
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
  if (focusStatus.authorization === 'authorized' && focusStatus.isFocused !== null) {
    const focusSwitch = document.getElementById('toggle-focus');
    if (focusSwitch.checked !== focusStatus.isFocused) throw new Error('Focus switch disagrees with macOS');
    if (focusStatus.isFocused && document.getElementById('app').dataset.engaged !== 'true' && !focusSwitch.disabled)
      throw new Error('An existing user Focus must remain protected');
  }
  const screenRecording = await craft.permissions.check('screen_recording');
  const accessibility = await craft.permissions.check('accessibility');
  if (screenRecording !== 'granted' && screenRecording !== 'denied') throw new Error('Screen Recording must use the real macOS permission API');
  let liveSharingVerified = false;
  let focusPreservationSettled = false;
  let liveSharingSources = [];
  await stage('live sharing');
  ${observeSharing ? `
  if (state.sharing) throw new Error('The live test must start idle, before sharing begins: ' + JSON.stringify(state));
  if (!document.getElementById('pref-automatic').checked) throw new Error('Live checks require automatic Focus enabled');
  if (screenRecording !== 'granted' || focusStatus.authorization !== 'authorized' || focusStatus.isFocused !== ${!exerciseFocus})
    throw new Error('Live check requires granted permissions and ${exerciseFocus ? 'no active' : 'an existing user'} Focus');
  async function waitForSharing(expected) {
    const deadline = Date.now() + 120000;
    while (document.getElementById('app').dataset.sharing !== String(expected)) {
      if (Date.now() > deadline) {
        const latest = await craft.screenSharing.getState();
        throw new Error('The native sharing transition did not reach the shipped client: ' + JSON.stringify({ expected, latest, status: document.getElementById('status').textContent, sharing: document.getElementById('app').dataset.sharing }));
      }
      await craft.timers.sleep(250);
    }
  }
  await stage('waiting for sharing to start');
  await craft.fs.writeFile(${JSON.stringify(join(root, 'dist/live-sharing-ready.json'))}, JSON.stringify({ ...${JSON.stringify(runMetadata)}, ready: true, state, focusStatus, screenRecording, accessibility }));
  await waitForSharing(true);
  ${exerciseFocus ? `
  const activationDeadline = Date.now() + 30000;
  while (document.getElementById('app').dataset.engaged !== 'true') {
    if (Date.now() > activationDeadline) throw new Error('Hush did not enable Focus: ' + document.getElementById('status').textContent);
    await craft.timers.sleep(250);
  }
  if ((await craft.focus.getStatus()).isFocused !== true) throw new Error('Automatic activation did not reach macOS');
  ` : `
  await stage('waiting for existing Focus preservation');
  const preservationDeadline = Date.now() + 120000;
  while (document.getElementById('app').dataset.transitionPending !== 'false') {
    if (document.getElementById('app').dataset.sharing !== 'true') throw new Error('Capture ended before the Focus policy settled');
    if (Date.now() > preservationDeadline) throw new Error('The Focus preservation policy did not settle');
    await craft.timers.sleep(250);
  }
  if (document.getElementById('app').dataset.sharing !== 'true') throw new Error('Capture ended before Focus preservation was verified');
  if (document.getElementById('app').dataset.engaged !== 'false' || (await craft.focus.getStatus()).isFocused !== true)
    throw new Error('Hush replaced the existing Focus');
  focusPreservationSettled = true;
  `}
  const liveState = await craft.screenSharing.getState();
  liveSharingSources = liveState.sources;
  ${expectedApp ? `
  if (!liveState.sources.some(source => source.app === ${JSON.stringify(expectedApp)}${expectedSource ? ` && source.window.toLowerCase().includes(${JSON.stringify(expectedSource.toLowerCase())})` : ''}))
    throw new Error('The expected app’s native sharing source was absent: ' + JSON.stringify(liveState));
  ` : ''}
  ${expectTabSharing ? `
  if (!liveState.sources.some(${isNativeTabSharing.toString()}))
    throw new Error('Expected a real native browser tab-capture indicator: ' + JSON.stringify(liveState));
  ` : ''}
  await craft.fs.writeFile(${JSON.stringify(join(root, 'dist/live-sharing-start.json'))}, JSON.stringify({ ...liveState, ...${JSON.stringify(runMetadata)} }));
  await stage('waiting for sharing to stop');
  await waitForSharing(false);
  ${exerciseFocus ? `
  await stage('waiting for automatic Focus release');
  const releaseDeadline = Date.now() + 30000;
  while (document.getElementById('app').dataset.engaged !== 'false') {
    if (Date.now() > releaseDeadline) throw new Error('Hush did not release Focus: ' + JSON.stringify({ latest: await craft.screenSharing.getState(), events: nativeSharingEvents, status: document.getElementById('status').textContent }));
    await craft.timers.sleep(250);
  }
  ` : ''}
  if ((await craft.focus.getStatus()).isFocused !== ${!exerciseFocus}) throw new Error('Unexpected macOS Focus after sharing');
  liveSharingVerified = true;
  ` : ''}
  await stage('native timers');
  const timerOrder = [];
  await Promise.all([
    craft.timers.sleep(80).then(() => timerOrder.push('slow')),
    craft.timers.sleep(5).then(() => timerOrder.push('fast')),
  ]);
  if (timerOrder.join(',') !== 'fast,slow') throw new Error('Native timer replies were misrouted');
  const cancellation = new AbortController();
  const cancelledTimer = craft.timers.sleep(60000, { signal: cancellation.signal })
    .then(() => { throw new Error('Cancelled native timer fired'); }, error => {
      if (error.name !== 'AbortError') throw error;
    });
  cancellation.abort();
  await cancelledTimer;
  let backgroundTimerMs = null;
  ${backgroundMs ? `
  await stage('background timer');
  const backgroundStarted = Date.now();
  await craft.timers.sleep(${backgroundMs});
  backgroundTimerMs = Date.now() - backgroundStarted;
  if (backgroundTimerMs > ${backgroundMs + 10_000}) throw new Error('The hidden native client delayed its background timer: ' + backgroundTimerMs);
  await craft.screenSharing.getState();
  ` : ''}
  if (typeof shortcuts.canList !== 'boolean') throw new Error('Invalid native shortcut response');
  await craft.fs.writeFile(${JSON.stringify(reportPath)}, JSON.stringify({ ready: true, nativeTray, nativeLoginEnabled, sharing: state.sharing, initialSources: state.sources, screenRecording, accessibility, canListShortcuts: shortcuts.canList, focusAuthorization: focusStatus.authorization, isFocused: focusStatus.isFocused, liveSharingVerified, liveSharingSources, nativeSharingEvents, backgroundTimerMs, focusPreservationSettled, focusShortcutsInstalled: shortcuts.shortcuts.includes('Hush Focus On') && shortcuts.shortcuts.includes('Hush Focus Off') }));
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
  const nativeStdout = join(work, 'native-stdout.log')
  const nativeStderr = join(work, 'native-stderr.log')
  writeFileSync(nativeStdout, '')
  writeFileSync(nativeStderr, '')
  writeFileSync(input, html.replace('</body>', `${assertions}</body>`))
  const started = performance.now()
  const nativeArgs = ['--html-file', input, ...(process.argv.includes('--verbose') ? ['--log-level', 'debug'] : [])]
  const args = launchServices
    ? ['open', '-W', '-n', '--stdout', nativeStdout, '--stderr', nativeStderr, bundle, '--args', ...nativeArgs]
    : [executable, ...nativeArgs]
  const child = Bun.spawn(args, { stdout: 'pipe', stderr: 'pipe' })
  // LaunchServices gives us an `open -W` waiter, not the app process. Bound
  // cleanup to this test's unique HTML argument so timeouts cannot leak an
  // app or terminate another Hush instance.
  function stopOwnedApp(signal: NodeJS.Signals): void {
    const snapshot = Bun.spawnSync(['ps', '-axo', 'pid=,args=']).stdout.toString()
    for (const line of snapshot.split('\n')) {
      const match = line.match(/^\s*(\d+)\s+(.+)$/)
      if (match?.[2]?.startsWith(`${executable} `) && match[2].includes(`--html-file ${input}`)) {
        try { process.kill(Number(match[1]), signal) }
        catch { /* The test app may already have exited. */ }
      }
    }
  }
  let timedOut = false
  const timeout = setTimeout(() => {
    timedOut = true
    stopOwnedApp('SIGTERM')
    child.kill()
  }, budget)
  const forceTimeout = setTimeout(() => stopOwnedApp('SIGKILL'), budget + 2000)
  const [launcherStdout, launcherStderr, exitCode] = await Promise.all([
    new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited,
  ]).finally(() => {
    clearTimeout(timeout)
    clearTimeout(forceTimeout)
    stopOwnedApp(timedOut ? 'SIGKILL' : 'SIGTERM')
  })
  const stdout = launcherStdout + (launchServices ? readFileSync(nativeStdout, 'utf8') : '')
  const stderr = launcherStderr + (launchServices ? readFileSync(nativeStderr, 'utf8') : '')
  if (process.argv.includes('--verbose')) {
    process.stdout.write(stdout)
    process.stderr.write(stderr)
  }
  if (timedOut || exitCode !== 0) {
    const diagnostic = existsSync(reportPath) ? readFileSync(reportPath, 'utf8') : 'No native result was written.'
    throw new Error(`Native app ${timedOut ? 'timed out' : `exited with ${exitCode}`}: ${diagnostic}\n${stdout}${stderr}`)
  }
  const report = JSON.parse(readFileSync(reportPath, 'utf8'))
  if (report.error || report.ready !== true) throw new Error(`${report.error ?? 'Native app was not ready'}\n${stderr}`)
  report.minimumMacOS = minimum
  report.bundleBytes = bundleBytes
  report.nativeCheckMs = Math.round(performance.now() - started)
  report.launchServices = launchServices
  report.backgroundTimingVerified = backgroundMs > 0
  report.automaticFocusVerified = exerciseFocus
  const firstSharingEvent = report.nativeSharingEvents?.find((event: { at: number, state: { sharing: boolean } }) => event.state.sharing)
  report.initialIdleMs = firstSharingEvent ? firstSharingEvent.at - Date.parse(runMetadata.checkedAt) : null
  report.tabSharingVerified = report.liveSharingVerified === true && report.liveSharingSources.some(isNativeTabSharing)
  report.focusPreservationVerified = observeSharing && !exerciseFocus && report.liveSharingVerified === true && report.focusPreservationSettled === true
  Object.assign(report, runMetadata, { status: 'passed' })
  writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`)
  // eslint-disable-next-line no-console
  console.log('Native WebKit startup, filesystem, detection, shortcut enumeration and clean shutdown verified.')
}
catch (error) {
  writeFileSync(output, `${JSON.stringify({ ...runMetadata, status: 'failed', error: error instanceof Error ? error.message : String(error) }, null, 2)}\n`)
  throw error
}
finally {
  rmSync(work, { recursive: true, force: true })
}
