/** Platform-free fixture; native checks always use Craft's actual timer. */
export function mockBackgroundDelay(ms: number, options: { signal?: AbortSignal } = {}): Promise<void> {
  return new Promise((resolve, reject) => {
    const { signal } = options
    const timer = setTimeout(() => {
      signal?.removeEventListener('abort', cancel)
      resolve()
    }, ms)
    function cancel(): void {
      clearTimeout(timer)
      signal?.removeEventListener('abort', cancel)
      reject(new DOMException('Aborted', 'AbortError'))
    }
    if (signal?.aborted) cancel()
    else signal?.addEventListener('abort', cancel, { once: true })
  })
}
