//
//  Track.swift
//  ampt
//

import Foundation
import SwiftData

@Model
final class Track {
    var bookmarkData: Data
    var title: String
    var artist: String?
    var album: String?
    var trackNumber: Int?
    var duration: TimeInterval?
    var order: Int
    var dateAdded: Date

    init(fileURL: URL, title: String? = nil, artist: String? = nil, album: String? = nil, trackNumber: Int? = nil, duration: TimeInterval? = nil, order: Int = 0) throws {
        self.bookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.title = title ?? fileURL.deletingPathExtension().lastPathComponent
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.duration = duration
        self.order = order
        self.dateAdded = Date()
    }

    /// Formatted display name (Artist - Title or just Title)
    var displayName: String {
        if let artist = artist, !artist.isEmpty {
            return "\(artist) - \(title)"
        }
        return title
    }

    /// Resolves the security-scoped bookmark, refreshing it if the system
    /// reports it stale. Does not start access; see `TrackAccess`.
    func resolveURL() -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale,
           let newData = try? url.bookmarkData(
               options: .withSecurityScope,
               includingResourceValuesForKeys: nil,
               relativeTo: nil
           ) {
            bookmarkData = newData
        }

        return url
    }
}

/// An open security scope on a track's file. Access is held for the
/// lifetime of the object and released in `deinit`, so holding exactly one
/// of these in the player guarantees balanced start/stop calls regardless
/// of how SwiftData materialises `Track` instances.
final class TrackAccess {
    let url: URL
    private let scoped: Bool

    init?(track: Track) {
        guard let url = track.resolveURL() else { return nil }
        scoped = url.startAccessingSecurityScopedResource()
        guard scoped || FileManager.default.isReadableFile(atPath: url.path) else {
            return nil
        }
        self.url = url
    }

    deinit {
        if scoped {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
