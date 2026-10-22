import { expect, it } from 'bun:test'
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { nativeArtifactSha256 } from '../scripts/native-artifact'

it('invalidates live evidence when resources change without changing the executable', () => {
  const bundle = mkdtempSync(join(tmpdir(), 'hush-artifact-test-'))
  try {
    mkdirSync(join(bundle, 'Contents/MacOS'), { recursive: true })
    mkdirSync(join(bundle, 'Contents/Resources'))
    writeFileSync(join(bundle, 'Contents/MacOS/Hush'), 'unchanged runtime')
    const resource = join(bundle, 'Contents/Resources/index.html')
    writeFileSync(resource, 'first application')
    const first = nativeArtifactSha256(bundle)
    expect(nativeArtifactSha256(bundle)).toBe(first)
    writeFileSync(resource, 'changed application')
    expect(nativeArtifactSha256(bundle)).not.toBe(first)
    writeFileSync(resource, 'first application')
    expect(nativeArtifactSha256(bundle)).toBe(first)
  }
  finally {
    rmSync(bundle, { recursive: true, force: true })
  }
})
