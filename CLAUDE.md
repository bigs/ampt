# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ampt is a macOS music player built with Swift/SwiftUI and SwiftData for persistence. It supports a persistent playlist, audio playback with transport controls, macOS media remote integration, a dock menu, and a Metal shader visualizer with a live-editable shader library.

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
- `ampt/amptApp.swift` - App entry point, SwiftData container (falls back to in-memory if the store won't open), `AppDelegate` (dock menu, folder drops on the dock icon), `AmptDocumentController` for dock icon file drops
- `ampt/ContentView.swift` - Main playlist view with drag-and-drop, recursive folder import with concurrent metadata reads, and playback controls
- `ampt/Track.swift` - SwiftData `@Model` for playlist tracks (pure data + bookmark resolution); `TrackAccess` holds an open security scope for exactly one file
- `ampt/PlayerState.swift` - Playback orchestration (current track, next/previous, playlist state). Owns the `TrackAccess`; tracks that fail to open are flagged in `unavailableTrackIDs` and skipped, never deleted
- `ampt/AudioPlayer.swift` - `AVAudioEngine`/`AVAudioPlayerNode` wrapper with progress timer, FFT spectrum tap, and output-device-change recovery
- `ampt/PlayerControlsView.swift` - Transport controls, progress bar, volume slider
- `ampt/MediaRemoteManager.swift` - macOS Control Center / headphone / keyboard media key integration
- `ampt/MetadataReader.swift` - Async metadata extraction via `AVURLAsset`
- `ampt/AudioAnalyzer.swift`, `VisualizerRenderer.swift`, `MetalVisualizerView.swift`, `VisualizerWindow.swift` - Visualizer: renderer samples the analyzer once per frame; shaders are compiled at runtime from the active `Shader` model's source (no precompiled `.metal`)
- `ampt/Shader.swift`, `ShaderLibraryView.swift`, `ShaderFileWatcher.swift` - Shader library with external-editor live reload
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
