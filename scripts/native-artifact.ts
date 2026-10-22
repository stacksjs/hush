import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

/** Include signed resources as well as the executable in live-test identity. */
export function nativeArtifactSha256(bundle: string): string {
  const hash = new Bun.CryptoHasher('sha256')
  function visit(relative: string): void {
    const path = join(bundle, relative)
    if (statSync(path).isDirectory()) {
      for (const name of readdirSync(path).sort()) visit(join(relative, name))
      return
    }
    const data = readFileSync(path)
    hash.update(`${relative}\0${data.byteLength}\0`)
    hash.update(data)
  }
  visit('')
  return hash.digest('hex')
}
