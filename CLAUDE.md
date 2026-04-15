# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ampt is a macOS music player built with Swift/SwiftUI and SwiftData for persistence. It supports a persistent playlist, audio playback with transport controls, macOS media remote integration, and a dynamic dock icon that shows playback progress.

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
- `ampt/amptApp.swift` - App entry point, SwiftData container, `AmptDocumentController` for dock icon file drops
- `ampt/ContentView.swift` - Main playlist view with drag-and-drop, file import, and playback controls
- `ampt/Track.swift` - SwiftData `@Model` for playlist tracks with security-scoped bookmarks
- `ampt/PlayerState.swift` - Playback orchestration (current track, next/previous, playlist state)
- `ampt/AudioPlayer.swift` - `AVAudioPlayer` wrapper with progress timer
- `ampt/PlayerControlsView.swift` - Transport controls, progress bar, volume slider
- `ampt/MediaRemoteManager.swift` - macOS Control Center / headphone / keyboard media key integration
- `ampt/MetadataReader.swift` - Async metadata extraction via `AVURLAsset`
- `ampt/DockMenuManager.swift` - Right-click dock icon context menu
- `ampt/DockIconUpdater.swift` - Dynamic dock icon with playback progress spiral
- `ampt/SpiralIconGenerator.swift` - Generates the spiral progress icon
- `ampt/Info.plist` - Declares audio file document types for dock icon drag-and-drop

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
