//
//  MetadataReader.swift
//  ampt
//

import Foundation
import AVFoundation

struct TrackMetadata {
    var title: String?
    var artist: String?
    var album: String?
    var duration: TimeInterval?
}

enum MetadataReader {
    static func read(from url: URL) async -> TrackMetadata {
        let asset = AVURLAsset(url: url)

        var metadata = TrackMetadata()

        // Get duration
        if let duration = try? await asset.load(.duration) {
            metadata.duration = duration.seconds
        }

        // Get metadata items
        if let metadataItems = try? await asset.load(.metadata) {
            for item in metadataItems {
                guard let key = item.commonKey?.rawValue,
                      let value = try? await item.load(.stringValue) else {
                    continue
                }

                switch key {
                case "title":
                    metadata.title = value
                case "artist":
                    metadata.artist = value
                case "albumName":
                    metadata.album = value
                default:
                    break
                }
            }
        }

        return metadata
    }
}
