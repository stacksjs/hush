# Hush Development Guide

This document outlines the development process and CI/CD setup for the Hush application.

## Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests locally
5. Submit a pull request

## Continuous Integration

We use GitHub Actions for continuous integration. When you submit a pull request or push to the main branch, the following checks are automatically run:

### Tests

The CI workflow automatically runs the Swift Package Manager tests for the HushLib library, which contains the core functionality of the app.

To run tests locally:

```sh
swift test
```

### Linting

The CI workflow uses SwiftLint to check code style and identify potential issues. 

To run the linter locally:

```sh
brew install swiftlint
swiftlint lint Hush
```

You can also install SwiftLint as a build phase in Xcode to get real-time feedback:

1. Open your target's Build Phases tab
2. Click the + button and select "New Run Script Phase"
3. Add the following script:
   ```sh
   if which swiftlint > /dev/null; then
     swiftlint
   else
     echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
   fi
   ```

### Build Validation

The CI workflow builds the app in Debug mode without code signing to ensure it compiles correctly.

To build locally:

```sh
cd Hush
xcodebuild build -project Hush.xcodeproj -scheme Hush -configuration Debug
```

## Release Process

For the release process, please refer to the [RELEASE.md](RELEASE.md) document.

## Code Organization

- **Hush/**: Main app code
  - **HushLib/**: Core functionality
  - **HushTests/**: Tests for the core functionality
  - **Hush.xcodeproj/**: Xcode project file

## Design Guidelines

1. **Separation of Concerns**: Keep UI logic separate from business logic
2. **Testability**: Make sure core functionality is testable
3. **Consistency**: Follow Apple's Human Interface Guidelines
4. **Privacy**: Respect user privacy and use the least amount of permissions necessary

## Common Issues

### Code Signing Problems

If you encounter code signing issues, you can build without code signing for development:

```sh
xcodebuild build -project Hush.xcodeproj -scheme Hush -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

### SwiftLint Warnings

To resolve common SwiftLint warnings:

- **Unused Imports**: Remove any imports that aren't used in the file
- **Force Unwrapping**: Use optional binding (`if let`) or nil coalescing (`??`) instead of `!`
- **Force Try**: Use `try?` or proper error handling instead of `try!` 