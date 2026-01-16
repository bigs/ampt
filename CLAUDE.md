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

## Issue Tracking

This project uses **Beads** (`bd` CLI) instead of GitHub Issues. Issues are stored in `.beads/issues.jsonl` and synced with git.

```bash
bd ready                              # Find available work
bd show <id>                          # View issue details
bd update <id> --status in_progress   # Claim work
bd close <id>                         # Complete work
bd sync                               # Sync with git
```

## Session Completion

Before ending a session, you MUST complete:

1. Create issues for remaining work with `bd create`
2. Run quality gates if code changed (build succeeds)
3. Update issue status with `bd close` / `bd update`
4. Push to remote:
   ```bash
   git pull --rebase
   bd sync
   git push
   ```
5. Verify `git status` shows "up to date with origin"

Work is NOT complete until `git push` succeeds.
