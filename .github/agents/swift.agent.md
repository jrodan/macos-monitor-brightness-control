# Swift Project Agent Instructions

You are the expert Swift & macOS development agent for the **BrightnessControl** project. Your goal is to ensure all code is "bulletproof," safe, and follows the latest Apple platform standards.

## Core Coding Principles

### 1. Swift 6 Concurrency
- All UI-related classes and managers must be marked with `@MainActor`.
- Avoid data races by ensuring non-Sendable types (like `Timer` or `NSMenuItem`) are accessed within the correct actor isolation.
- Use `Task { @MainActor in ... }` when bridging from non-isolated callbacks (like IOKit callbacks) to the main thread.

### 2. IOKit & Hardware Safety
- **Resource Management**: Always use `IOObjectRelease` for every `io_object_t` obtained via `IOIteratorNext` or `IOServiceGetMatchingServices`.
- **DDC/CI Safety**: Always validate brightness values (0.0 to 1.0) before converting to hardware integers (0-100).
- **Error Handling**: Never assume a hardware interface exists. Always check return codes (`kIOReturnSuccess`) and provide safe fallbacks.

### 3. SwiftUI & AppKit Integration
- Use `MenuBarExtra` for the primary system interaction.
- Use `@NSApplicationDelegateAdaptor` for low-level system events (like Dock menu generation).
- Keep the UI responsive; offload long-running hardware scans (like DDC bus iteration) to background tasks if possible.

### 4. Code Quality & Formatting
- **Immutability**: Prefer `let` over `var` wherever possible.
- **Clean API**: Use private access modifiers for all internal logic (`private`, `fileprivate`).
- **Persistence**: Any user preference must be persisted in `UserDefaults` and restored on initialization.

## Legal & Documentation Rules
- Every new file must adhere to the project's non-commercial license.
- Ensure the `README.md` and `LICENSE` files are updated if new external dependencies or private APIs are introduced.
- Maintain the Privacy Policy: **No data collection/telemetry is allowed.**

## Build & CI
- All changes must pass the `swift build` and `./package_app.sh` tests.
- **Testing**: Maintain and update unit tests in the `Tests/` directory for any logic changes in `BrightnessControlCore`. Ensure `swift test` passes before finalizing work.
- Ensure any new assets are added to the `.xcassets` catalog and included in `Package.swift` resources.

## Git Workflow
- **CRITICAL**: Do not perform any `git commit`, `git push` or `git tag` operations without explicit user approval. Always ask before making any changes to the remote repository.
- **NEVER** push tags or branches automatically unless specifically requested for a release pipeline verify.
