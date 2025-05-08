# Release Guide

This document outlines the process for creating and publishing new releases of Hush.

## Prerequisites

- Push access to the repository
- Access to code signing certificates (for notarized builds)
- GitHub token with appropriate permissions
- Xcode 16 or later (for Swift 6 support)

### GitHub Secrets Configuration

For the automated release process to work, you need to configure the following GitHub Secrets in your repository settings:

1. **MACOS_CERT_P12**: Base64-encoded macOS signing certificate
2. **MACOS_CERT_PASSWORD**: Password for the macOS signing certificate
3. **APPLE_TEAM_ID**: Your Apple Developer Team ID
4. **APPLE_ID**: The Apple ID email used for notarization
5. **APPLE_ID_PASSWORD**: An app-specific password for your Apple ID
6. **GITHUB_TOKEN**: Automatically provided by GitHub Actions

#### Exporting Your Certificates

To export your signing certificates for the MACOS_CERT_P12 secret:

1. Open Keychain Access on your Mac
2. Select the certificates and their associated private keys
3. Right-click and select "Export Items..."
4. Save as a `.p12` file with a strong password
5. Convert to base64 with the following command:
   ```sh
   base64 -i cert.p12 | pbcopy
   ```
6. Add the output as the `MACOS_CERT_P12` secret in GitHub

For the APPLE_ID_PASSWORD, create an app-specific password in your Apple ID account settings.

## Automated Release Process

Our releases are automated using GitHub Actions and the [action-releaser](https://github.com/stacksjs/action-releaser) GitHub Action, with full support for Swift 6.

### Version Management

1. Update version numbers in:
   - `Hush/Hush/Info.plist`
   - Any other relevant files mentioning version

2. Update the `CHANGELOG.md` with your new version and detailed release notes in the format:

```markdown
## X.Y.Z - YYYY-MM-DD

### Added
- New feature A
- New feature B

### Changed
- Improvement to feature C
- Updated dependency X

### Fixed
- Bug in feature D
- Issue with component E
```

3. Commit these changes to the repository.

### Creating a Release

1. Tag the release with a semantic version:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

2. The GitHub Actions release workflow will automatically:
   - Build the app
   - Code sign it
   - Create a DMG
   - Notarize the DMG with Apple
   - Create a GitHub Release with release notes from the CHANGELOG
   - Attach the DMG to the release
   - Update the Homebrew formula (if configured)

3. The entire process typically takes 10-15 minutes. You can monitor progress in the Actions tab of the GitHub repository.

### Release Artifacts

The release will produce:
- A signed, notarized DMG file named `Hush-vX.Y.Z.dmg`
- A GitHub Release at `https://github.com/username/hush/releases/tag/vX.Y.Z`

## Swift 6 Compatibility

Hush is built with Swift 6, which brings several improvements to our codebase:

- **Data-race safety**: Swift 6 adds compile-time protection against data races in concurrent code.
- **Improved performance**: Optimizations in Swift 6 improve performance across the application.
- **Typed throws**: Swift 6 enables functions to specify exactly what error types they can throw.
- **Synchronization library**: Access to low-level concurrency primitives for fine-grained control.
- **Swift Testing**: Improved testing capabilities with the new Swift Testing framework.

### Known Issues

If you encounter any issues related to Swift 6 compatibility, please report them in our issue tracker.

## Homebrew Integration (Optional)

To enable automatic Homebrew formula updates:

1. Ensure you have a Homebrew tap repository (e.g., `username/homebrew-tap`)
2. Configure the following in `.github/workflows/release.yml`:
   - Uncomment and update the Homebrew configuration
   - Set the correct `homebrewRepo` value
3. Update `homebrew-formula.rb.template` with correct SHA256 checksums after the first manual release

## Manual Release (Fallback)

If the automated process fails, you can perform a manual release:

1. Build the app in Xcode:
   - Select Product > Archive
   - Use the Organizer to export a Developer ID signed application

2. Create a DMG using `create-dmg`:
```bash
create-dmg \
  --volname "Hush" \
  --volicon "path/to/icon.icns" \
  --window-pos 200 120 \
  --window-size 800 450 \
  --icon-size 100 \
  --app-drop-link 600 165 \
  --icon "Hush.app" 200 165 \
  "Hush-vX.Y.Z.dmg" \
  "path/to/Hush.app"
```

3. Notarize the DMG:
```bash
xcrun notarytool submit Hush-vX.Y.Z.dmg \
  --apple-id "your-apple-id" \
  --password "app-specific-password" \
  --team-id "your-team-id" \
  --wait

xcrun stapler staple Hush-vX.Y.Z.dmg
```

4. Create a GitHub Release manually through the web interface.

## Troubleshooting

Common issues and their solutions:

### Code Signing Issues
- Ensure certificates are correctly installed in the GitHub Actions keychain
- Check certificate expiration dates
- Verify team ID matches in the exportOptions.plist

### Notarization Issues
- Check Apple ID and password are correct
- Verify app is signed with the correct identity
- Look for security or entitlement issues using `codesign -dvvv`

### DMG Creation Issues
- Verify the path to assets (background, icons)
- Check if app is exported to the expected location

For more help, contact the repository maintainers. 