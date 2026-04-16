//
//  ContentView.swift
//  ampt
//
//  Created by Cole Brown on 1/16/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dockIconUpdater) private var dockIconUpdater
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Track.order) private var tracks: [Track]
    var playerState: PlayerState
    var fileDropCoordinator: FileDropCoordinator
    @State private var isDropTargeted = false
    @State private var selectedTrackIDs: Set<Track.ID> = []

    private let validExtensions: Set<String> = ["mp3", "flac", "m4a", "aac", "wav", "aiff", "alac"]

    var body: some View {
        VStack(spacing: 0) {
            PlayerControlsView(state: playerState)
            Divider()
            playlistView
        }
        .frame(minWidth: 280, idealWidth: 320, minHeight: 300)
        .overlay { dropOverlay }
        .toolbar { toolbarContent }
        .dropDestination(for: URL.self) { urls, _ in
            addURLs(urls)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .onChange(of: tracks) { _, newTracks in
            playerState.updatePlaylist(newTracks)
        }
        .onChange(of: fileDropCoordinator.pendingURLs) { _, newURLs in
            guard !newURLs.isEmpty else { return }
            fileDropCoordinator.pendingURLs = []
            addURLs(newURLs, playFirst: true)
        }
        .onAppear {
            cleanupInvalidTracks()
            playerState.updatePlaylist(tracks)
            // Process any URLs that arrived before the view appeared
            if !fileDropCoordinator.pendingURLs.isEmpty {
                let urls = fileDropCoordinator.pendingURLs
                fileDropCoordinator.pendingURLs = []
                addURLs(urls, playFirst: true)
            }
            // Dynamic icon disabled for now due to sizing/rendering issues
            // dockIconUpdater?.startObserving(playerState: playerState)
        }
        .onDisappear {
            // dockIconUpdater?.stopObserving()
        }
        .onKeyPress(.space) {
            playerState.togglePlayPause()
            return .handled
        }
    }

    @ViewBuilder
    private var playlistView: some View {
        List(selection: $selectedTrackIDs) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                let isCurrentTrack = playerState.currentTrack?.id == track.id
                let isPlaying = playerState.isPlaying

                TrackRow(track: track, playlistNumber: index + 1, isCurrentTrack: isCurrentTrack, isPlaying: isPlaying)
                    .tag(track.id)
                    .contextMenu {
                        Button("Play") {
                            playerState.play(track: track, at: index)
                        }
                        Divider()
                        Button("Remove", role: .destructive) {
                            deleteTrack(track)
                        }
                    }
            }
            .onMove(perform: moveTracks)
        }
        .contextMenu(forSelectionType: Track.ID.self) { ids in
            if ids.isEmpty {
                // Background context menu
            } else {
                Button("Remove \(ids.count == 1 ? "Track" : "\(ids.count) Tracks")", role: .destructive) {
                    deleteTracksWithIDs(ids)
                }
            }
        } primaryAction: { ids in
            // Double-click action
            if let id = ids.first,
               let index = tracks.firstIndex(where: { $0.id == id }) {
                playerState.play(track: tracks[index], at: index)
            }
        }
        .onDeleteCommand {
            deleteTracksWithIDs(selectedTrackIDs)
        }
        .overlay {
            if tracks.isEmpty {
                ContentUnavailableView {
                    Label("No Tracks", systemImage: "music.note")
                } description: {
                    Text("Drop audio files or click + to add")
                }
            }
        }
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 3)
                .padding(4)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button { openWindow(id: "visualizer") } label: {
                Label("Visualizer", systemImage: "waveform")
            }
        }
        ToolbarItem {
            Button(action: openFiles) {
                Label("Add Files", systemImage: "plus")
            }
        }
    }

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .aiff, .wav]

        if panel.runModal() == .OK {
            addURLs(panel.urls)
        }
    }

    private func addURLs(_ urls: [URL], playFirst: Bool = false) {
        var allFiles: [URL] = []
        for url in urls {
            allFiles.append(contentsOf: collectAudioFiles(from: url))
        }

        let startOrder = tracks.count
        Task {
            for (index, fileURL) in allFiles.enumerated() {
                let metadata = await MetadataReader.read(from: fileURL)

                await MainActor.run {
                    do {
                        let track = try Track(
                            fileURL: fileURL,
                            title: metadata.title,
                            artist: metadata.artist,
                            album: metadata.album,
                            trackNumber: metadata.trackNumber,
                            duration: metadata.duration,
                            order: startOrder + index
                        )
                        modelContext.insert(track)
                        if playFirst && index == 0 {
                            playerState.play(track: track, at: startOrder)
                        }
                    } catch {
                        print("Failed to create bookmark for \(fileURL.lastPathComponent): \(error)")
                    }
                }
            }
        }
    }

    private func collectAudioFiles(from url: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }

        if isDirectory.boolValue {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            return contents
                .filter { validExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } else {
            if validExtensions.contains(url.pathExtension.lowercased()) {
                return [url]
            }
            return []
        }
    }

    private func deleteTrack(_ track: Track) {
        if playerState.isCurrentTrack(track) {
            playerState.clearCurrentTrack()
        }
        withAnimation {
            modelContext.delete(track)
            try? modelContext.save()
        }
    }

    private func deleteTracksWithIDs(_ ids: Set<Track.ID>) {
        for track in tracks where ids.contains(track.id) {
            if playerState.isCurrentTrack(track) {
                playerState.clearCurrentTrack()
            }
        }
        withAnimation {
            for track in tracks where ids.contains(track.id) {
                modelContext.delete(track)
            }
            selectedTrackIDs.subtract(ids)
            try? modelContext.save()
        }
    }

    private func moveTracks(from source: IndexSet, to destination: Int) {
        var reorderedTracks = tracks
        reorderedTracks.move(fromOffsets: source, toOffset: destination)
        for (index, track) in reorderedTracks.enumerated() {
            track.order = index
        }
    }

    private func cleanupInvalidTracks() {
        let invalidTracks = tracks.filter { !$0.isValid }
        if !invalidTracks.isEmpty {
            for track in invalidTracks {
                modelContext.delete(track)
            }
            print("Removed \(invalidTracks.count) invalid track(s)")
        }
    }
}

struct TrackRow: View {
    let track: Track
    let playlistNumber: Int
    let isCurrentTrack: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Playlist number
            Text("\(playlistNumber).")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 24, alignment: .trailing)

            // Title
            Text(track.title)
                .lineLimit(1)
                .truncationMode(.tail)

            // Artist (if available)
            if let artist = track.artist, !artist.isEmpty {
                Text(artist)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            // Album info (track#, album) if available
            if track.trackNumber != nil || track.album != nil {
                Text(albumInfo)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150, alignment: .trailing)
            }

            // Playing indicator
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(isPlaying ? Color.accentColor : .secondary)
                .font(.caption)
                .frame(width: 16)
                .opacity(isCurrentTrack ? 1 : 0)
        }
    }

    private var albumInfo: String {
        switch (track.trackNumber, track.album) {
        case let (num?, album?) where !album.isEmpty:
            return "(\(num), \(album))"
        case let (num?, _):
            return "(\(num))"
        case let (_, album?) where !album.isEmpty:
            return "(\(album))"
        default:
            return ""
        }
    }
}

#Preview {
    ContentView(playerState: PlayerState(), fileDropCoordinator: .shared)
        .modelContainer(for: Track.self, inMemory: true)
}
