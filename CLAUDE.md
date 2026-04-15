# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ampt is a macOS desktop application built with Swift/SwiftUI and SwiftData for persistence. It's currently a starter template with basic list/detail navigation for managing timestamped items.

## Build Commands

```bash
# Open in Xcode
open ampt.xcodeproj

# Build from command line
xcodebuild -scheme ampt -configuration Debug build
xcodebuild -scheme ampt -configuration Release build
```

No package managers (SPM, CocoaPods) are configured - all dependencies are system frameworks.

## Architecture

**Tech Stack:**
- SwiftUI for UI
- SwiftData for persistence
- macOS 26.1+ deployment target

**Key Files:**
- `ampt/amptApp.swift` - App entry point, configures SwiftData ModelContainer
- `ampt/ContentView.swift` - Main NavigationSplitView with list/detail layout
- `ampt/Item.swift` - SwiftData @Model for timestamped items

**Security:**
- App Sandbox enabled
- Hardened Runtime enabled

## Session Completion

Before ending a session, you MUST complete:

1. Run quality gates if code changed (build succeeds)
2. Push to remote:
   ```bash
   git pull --rebase
   git push
   ```
3. Verify `git status` shows "up to date with origin"

Work is NOT complete until `git push` succeeds.
