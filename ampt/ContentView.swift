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
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Track.order) private var tracks: [Track]
    var playerState: PlayerState
    var fileDropCoordinator: FileDropCoordinator
    @State private var isDropTargeted = false
    @State private var selectedTrackIDs: Set<Track.ID> = []

    /// Single source of truth for what counts as an audio file, for both the
    /// open panel and drop/folder filtering.
    private nonisolated static let audioExtensions: Set<String> = ["mp3", "flac", "m4a", "aac", "wav", "aiff", "aif", "alac"]
    private static let audioContentTypes: [UTType] = audioExtensions.compactMap { UTType(filenameExtension: $0) }

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
            playerState.updatePlaylist(tracks)
            // Process any URLs that arrived before the view appeared
            if !fileDropCoordinator.pendingURLs.isEmpty {
                let urls = fileDropCoordinator.pendingURLs
                fileDropCoordinator.pendingURLs = []
                addURLs(urls, playFirst: true)
            }
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
                let isUnavailable = playerState.unavailableTrackIDs.contains(track.id)

                TrackRow(track: track, playlistNumber: index + 1, isCurrentTrack: isCurrentTrack, isPlaying: isPlaying, isUnavailable: isUnavailable)
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
            Button { toggleWindow(id: "visualizer", title: "ampt Visualizer") } label: {
                Label("Visualizer", systemImage: "waveform")
            }
        }
        ToolbarItem {
            Button { toggleWindow(id: "shader-library", title: "Shader Library") } label: {
                Label("Shaders", systemImage: "slider.horizontal.3")
            }
        }
        ToolbarItem {
            Button(action: openFiles) {
                Label("Add Files", systemImage: "plus")
            }
        }
    }

    private func toggleWindow(id: String, title: String) {
        if let existing = NSApp.windows.first(where: { $0.title == title }) {
            existing.close()
        } else {
            openWindow(id: id)
        }
    }

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = Self.audioContentTypes

        if panel.runModal() == .OK {
            addURLs(panel.urls)
        }
    }

    private func addURLs(_ urls: [URL], playFirst: Bool = false) {
        let files = urls.flatMap(Self.collectAudioFiles)
        guard !files.isEmpty else { return }

        // Orders aren't contiguous after removals, so append past the max.
        let startOrder = (tracks.map(\.order).max() ?? -1) + 1
        let firstIndex = tracks.count
        Task {
            // Read metadata concurrently; results keep the enumeration order so
            // the playlist order matches the folder listing.
            let metadata = await withTaskGroup(of: (Int, TrackMetadata).self) { group in
                for (index, url) in files.enumerated() {
                    group.addTask { (index, await MetadataReader.read(from: url)) }
                }
                var results = [TrackMetadata?](repeating: nil, count: files.count)
                for await (index, meta) in group {
                    results[index] = meta
                }
                return results
            }

            var firstTrack: Track?
            var order = startOrder
            for (url, meta) in zip(files, metadata) {
                let meta = meta ?? TrackMetadata()
                do {
                    let track = try Track(
                        fileURL: url,
                        title: meta.title,
                        artist: meta.artist,
                        album: meta.album,
                        trackNumber: meta.trackNumber,
                        duration: meta.duration,
                        order: order
                    )
                    modelContext.insert(track)
                    if firstTrack == nil { firstTrack = track }
                    order += 1
                } catch {
                    print("Failed to create bookmark for \(url.lastPathComponent): \(error)")
                }
            }
            try? modelContext.save()

            if playFirst, let firstTrack {
                playerState.play(track: firstTrack, at: firstIndex)
            }
        }
    }

    /// Expands a dropped/picked URL into audio files. Folders are walked
    /// recursively and sorted by path so album folders import in order.
    private nonisolated static func collectAudioFiles(from url: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }
        guard isDirectory.boolValue else {
            return isAudioFile(url) ? [url] : []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator where isAudioFile(fileURL) {
            let isRegular = (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            if isRegular { files.append(fileURL) }
        }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private nonisolated static func isAudioFile(_ url: URL) -> Bool {
        audioExtensions.contains(url.pathExtension.lowercased())
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
        try? modelContext.save()
    }
}

struct TrackRow: View {
    let track: Track
    let playlistNumber: Int
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let isUnavailable: Bool

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

            // Trailing status: unavailable warning, or playing indicator
            if isUnavailable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                    .frame(width: 16)
                    .help("File could not be opened. Is its drive mounted?")
            } else {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(isPlaying ? Color.accentColor : .secondary)
                    .font(.caption)
                    .frame(width: 16)
                    .opacity(isCurrentTrack ? 1 : 0)
            }
        }
        .opacity(isUnavailable ? 0.5 : 1)
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
