# Contributing to Hush

Thank you for considering contributing to Hush! This document outlines the process for contributing to the project.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to [project maintainers].

## How Can I Contribute?

### Reporting Bugs

- **Check if the bug has already been reported** by searching the Issues.
- If you're unable to find an open issue addressing the problem, open a new one.
- Include a **clear title and description**, as much relevant information as possible, and a **code sample** demonstrating the expected behavior that is not occurring.

### Suggesting Enhancements

- Open a new issue with a clear title and detailed description.
- Include any specific examples and context.
- Describe the current behavior and explain which behavior you expected to see instead.

### Your First Code Contribution

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/amazing-feature`).
3. Make your changes.
4. Run the tests (`swift test`).
5. Commit your changes (`git commit -m 'Add some amazing feature'`).
6. Push to the branch (`git push origin feature/amazing-feature`).
7. Open a Pull Request.

### Pull Requests

1. Update the README.md and documentation with details of changes if appropriate.
2. Update the CHANGELOG.md with details of changes.
3. The PR should work for macOS 12.0+.
4. Make sure the CI passes.

## Development Process

### Setting Up Development Environment

1. Install Xcode 14.0 or later.
2. Clone the repository.
3. Open `Hush.xcodeproj` in Xcode.

### Testing

- Make sure to write tests for new features or bug fixes.
- Run `swift test` to execute the test suite.

### Coding Style

- Follow the Swift API Design Guidelines.
- Use SwiftLint for code style validation.
- Run `swiftlint` before submitting PR to ensure your code follows our style.

### Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc)
- `refactor`: Code changes that neither fix bugs nor add features
- `test`: Adding or updating tests
- `chore`: Changes to the build process or auxiliary tools

Example: `feat: add support for screen sharing detection in Microsoft Teams`

## Release Process

For information about our release process, see [RELEASE.md](RELEASE.md).

## Questions?

Feel free to contact the project maintainers if you have any questions or need help getting started.

Thank you for contributing to Hush!