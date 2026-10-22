/** Match only the tab-capture sources emitted by Craft's native readers. */
export function isNativeTabSharing(source: { app: string, window: string }): boolean {
  return ((source.app === 'Dia' || source.app === 'Google Chrome') && source.window === 'Browser tab sharing')
    || (source.app === 'Google Chrome' && source.window.endsWith(' - Tab content shared - Google Chrome'))
}
