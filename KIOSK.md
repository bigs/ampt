# Installing ampt

ampt is a minimal Winamp-inspired audio player for macOS built with SwiftUI.

## Requirements

- macOS 26.1+
- Xcode 26+

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/bigs/ampt.git
   cd ampt
   ```

2. Build a release:
   ```bash
   xcodebuild -scheme ampt -configuration Release build
   ```

3. Open the built app:
   ```bash
   open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Release/ampt.app
   ```

## Features

- Drag & drop playlist - Drop audio files or folders to add tracks
- ID3 metadata display (artist, title, album, track number)
- Persistent playlist across app restarts
- Compact UI with sliding volume drawer
- Supports MP3, FLAC, M4A, AAC, WAV, AIFF, ALAC

## Usage

1. Launch the app
2. Drag audio files or folders onto the window (or click + to browse)
3. Double-click a track to play
4. Use transport controls or keyboard shortcuts
