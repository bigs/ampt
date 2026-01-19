# Installing ampt

> **Note to installing agent**: Use the question tool to present multiple choice options whenever you need user input. This makes installation easier.

A minimal Winamp-inspired audio player for macOS, built with SwiftUI.

## Prerequisites

- macOS 26.1 or later
- Xcode 26 or later

## Installation

1. Copy the project files to your desired location

2. Open in Xcode:
   ```bash
   open ampt.xcodeproj
   ```

3. Build and run:
   - Press `Cmd+R` in Xcode, or
   - Build from command line:
     ```bash
     xcodebuild -scheme ampt -configuration Release build
     ```

## Configuration

No configuration required. The app works out of the box.

- **Persistence**: SwiftData handles playlist storage automatically
- **Sandbox**: App is sandboxed with User Selected File access for audio files

## Usage

1. Launch the app
2. Drag audio files or folders onto the window (or click + to browse)
3. Double-click a track to play
4. Use transport controls or keyboard shortcuts

## Supported Formats

MP3, FLAC, M4A, AAC, WAV, AIFF, ALAC
