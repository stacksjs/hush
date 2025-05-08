# Changelog

All notable changes to the Hush app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.2.0 - 2024-09-25

### Changed
- Fully consolidated all Swift 6 features into the main codebase
- Added proper availability annotations for compatibility with earlier macOS versions
- Improved actor isolation and thread safety throughout the app
- Enhanced MainActor usage for UI thread safety
- Fixed atomic memory ordering in Swift 6 implementations
- Improved debug description macros for better debugging experience

### Removed
- Deleted redundant Swift 6 demo files and implementations
- Removed Swift6Demo directory and files
- Eliminated duplicate type declarations across files

## 1.1.0 - 2024-09-20

### Added
- Swift 6 compatibility with full data race safety
- New Swift Testing framework integration for improved test coverage
- Synchronization library usage for thread-safe operations
- Advanced debugging with @DebugDescription macro support
- Support for typed throws for more precise error handling
- Count(where:) method for efficient collection filtering
- Atomic operations with memory ordering control

### Changed
- Migrated shared mutable state to actor model for concurrency safety
- Improved async/await usage throughout the codebase
- Enhanced menu bar and status item behaviors
- Modernized UI interaction code with MainActor isolation
- Updated build pipeline for Swift 6 toolchain
- Refactored test expectations to use async/await pattern
- Improved state management with Atomic types
- Consolidated all Swift 6 features into the main codebase
- Unified test suite with integrated Swift 6 features

### Fixed
- Data race conditions in screen sharing detection
- Thread safety issues in preference handling
- Improved error handling with Swift 6's typed throws
- Memory leaks in notification observers
- Fixed test failures by properly awaiting asynchronous operations
- Eliminated redundant Swift 6 demo implementations

## 1.0.0 - 2024-05-07

### Added
- Initial release of Hush
- Automatic Do Not Disturb activation when screen sharing is detected
- Menu bar app with status indicator
- Preferences for customizing focus mode and duration
- Statistics tracking for screen sharing sessions
- Automatic launch at login option
- Welcome screen for new users

### Changed
- Improved welcome screen design with better spacing and visual elements
- Increased welcome screen size to 600x530 pixels

### Fixed
- Duplicated model declarations across files
- Issues with storyboard loading 