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
    var duration: TimeInterval?
    var order: Int
    var dateAdded: Date

    // Transient state (not persisted)
    @Transient var cachedURL: URL?
    @Transient var hasActiveAccess: Bool = false
    @Transient var needsSecurityScope: Bool = true

    init(fileURL: URL, title: String? = nil, order: Int = 0) throws {
        self.bookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.title = title ?? fileURL.deletingPathExtension().lastPathComponent
        self.duration = nil
        self.order = order
        self.dateAdded = Date()
        self.cachedURL = fileURL
        self.hasActiveAccess = true  // Already have access from picker/drop
        self.needsSecurityScope = false  // Don't need to call startAccessing
    }

    /// Resolves the security-scoped bookmark to get file access
    func resolveURL() -> URL? {
        if let cached = cachedURL {
            return cached
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            // Try to refresh the bookmark
            if let newData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                bookmarkData = newData
            }
        }

        cachedURL = url
        needsSecurityScope = true  // Resolved from bookmark, needs security scope
        return url
    }

    /// Start accessing the security-scoped resource
    func startAccessing() -> Bool {
        if hasActiveAccess {
            return true  // Already have access
        }

        guard let url = resolveURL() else { return false }

        if needsSecurityScope {
            hasActiveAccess = url.startAccessingSecurityScopedResource()
            return hasActiveAccess
        }

        hasActiveAccess = true
        return true
    }

    /// Stop accessing the security-scoped resource
    func stopAccessing() {
        if hasActiveAccess && needsSecurityScope {
            cachedURL?.stopAccessingSecurityScopedResource()
        }
        hasActiveAccess = false
    }

    /// Check if the track's file is still accessible
    var isValid: Bool {
        if cachedURL != nil {
            return true  // Fresh track from this session
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }

        // Check if file exists
        return FileManager.default.fileExists(atPath: url.path)
    }
}
