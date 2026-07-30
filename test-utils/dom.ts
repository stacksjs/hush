/**
 * Minimal `window` for Hush's controller tests.
 *
 * The bridge wrappers feature-detect with `typeof window === 'undefined'` and
 * deliver Craft's events as window events, so the tests need a global `window`
 * that is an event target and can hold `window.craft`. That is the entire
 * requirement — the controller never touches the DOM, so pulling in a full DOM
 * implementation would be weight without benefit.
 */
if (typeof (globalThis as { window?: unknown }).window === 'undefined') {
  const target = new EventTarget()

  // Bound, because the tests hand these around as bare functions and an
  // unbound EventTarget method throws on an illegal invocation.
  const win = {
    addEventListener: target.addEventListener.bind(target),
    removeEventListener: target.removeEventListener.bind(target),
    dispatchEvent: target.dispatchEvent.bind(target),
  }

  Object.defineProperty(globalThis, 'window', { value: win, configurable: true, writable: true })
}
