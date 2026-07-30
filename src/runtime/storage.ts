import { fs, shell } from '@stacksjs/desktop/browser'

/**
 * JSON documents in `~/Library/Application Support/Hush/`.
 *
 * Hush runs inside a Craft webview, so `node:fs` is not available — reads and
 * writes go through the Craft file bridge. Outside Craft (a browser during UI
 * work) every operation degrades to an in-memory map so the UI still runs
 * without a bridge to talk to.
 */

const APP_DIR_NAME = 'Hush'

let cachedDir: string | null = null
const memory = new Map<string, string>()

async function appDir(): Promise<string | null> {
  if (cachedDir) return cachedDir
  const home = await shell.getEnv('HOME')
  if (!home) return null
  cachedDir = `${home}/Library/Application Support/${APP_DIR_NAME}`
  return cachedDir
}

/**
 * Read a document, or `''` when it does not exist yet.
 *
 * A missing file is the normal first-run case, not an error — every caller
 * parses `''` into defaults, so failures here never need to reach the user.
 */
export async function readDocument(name: string): Promise<string> {
  const dir = await appDir()
  if (!dir) return memory.get(name) ?? ''
  try {
    const path = `${dir}/${name}`
    if (!await fs.exists(path)) return ''
    return await fs.readFile(path)
  }
  catch {
    return ''
  }
}

/**
 * Write a document, creating the directory on the way.
 *
 * Returns whether the write landed. Preferences that fail to persist should
 * still apply for the session, so the caller decides whether to surface it —
 * this never throws into the detection loop.
 */
export async function writeDocument(name: string, contents: string): Promise<boolean> {
  const dir = await appDir()
  if (!dir) {
    memory.set(name, contents)
    return true
  }
  try {
    await fs.mkdir(dir, { recursive: true })
    await fs.writeFile(`${dir}/${name}`, contents)
    return true
  }
  catch {
    return false
  }
}

/** Reset the resolved directory. Tests only. */
export function resetStorageCache(): void {
  cachedDir = null
  memory.clear()
}
