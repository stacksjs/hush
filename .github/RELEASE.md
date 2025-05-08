# Releasing Hush

This document explains how to create a new release of Hush using the GitHub Actions workflow.

## Prerequisites

Before you can release Hush, you need to set up the following GitHub Secrets in your repository settings:

1. **MACOS_CERT_P12**: Base64-encoded macOS signing certificate
2. **MACOS_CERT_PASSWORD**: Password for the macOS signing certificate
3. **APPLE_TEAM_ID**: Your Apple Developer Team ID
4. **APPLE_ID**: The Apple ID email used for notarization
5. **APPLE_ID_PASSWORD**: An app-specific password for your Apple ID

### Exporting Your Certificates

To export your signing certificates:

1. Open Keychain Access on your Mac
2. Select the certificates and their associated private keys
3. Right-click and select "Export Items..."
4. Save as a `.p12` file with a strong password
5. Convert to base64 with the following command:
   ```sh
   base64 -i cert.p12 | pbcopy
   ```
6. Add the output as the `MACOS_CERT_P12` secret in GitHub

## Creating a Release

To create a new release:

1. Update the version in your project's `Info.plist` file
2. Commit your changes and push to main
3. Create a new tag with the version number (must start with 'v'):
   ```sh
   git tag v1.0.0
   git push origin v1.0.0
   ```

This will trigger the GitHub Actions workflow, which will:

1. Run the tests
2. Build the Hush app
3. Sign the app with your certificate
4. Create a DMG installer
5. Notarize the app with Apple
6. Create a GitHub Release with the DMG attached

## Release Notes

If you have a `CHANGELOG.md` file in your repository with properly formatted version headers (e.g., `## 1.0.0`), the workflow will automatically extract the relevant section for the release notes.

## Troubleshooting

If the release workflow fails, check the following:

1. Ensure all required secrets are properly set up
2. Verify that your signing certificate is valid
3. Make sure your Apple Developer Program membership is active
4. Check that the Xcode project builds successfully locally

For more details, see the [GitHub Actions workflow logs](../../actions) in your repository. 