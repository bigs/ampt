# ampt

A minimal Winamp-inspired audio player for macOS, built with SwiftUI.

![screenshot](screenshot.png)

![macOS](https://img.shields.io/badge/macOS-26.1+-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)

## Features

- **Drag & drop playlist** - Drop audio files or folders to add tracks
- **ID3 metadata** - Displays artist, title, album, and track number
- **Persistent playlist** - Your playlist survives app restarts
- **Compact UI** - Small footprint, stays out of your way
- **Volume control** - Sliding drawer reveals volume slider

## Supported Formats

MP3, FLAC, M4A, AAC, WAV, AIFF, ALAC

## Building

```bash
# Open in Xcode
open ampt.xcodeproj

# Or build from command line
xcodebuild -scheme ampt -configuration Release build
```

Requires macOS 26.1+ and Xcode 26+.

## Usage

1. Launch the app
2. Drag audio files or folders onto the window (or click + to browse)
3. Double-click a track to play
4. Use transport controls or keyboard shortcuts

## License

MIT
