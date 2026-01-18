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
    var trackNumber: Int?
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

            // Track number - try multiple approaches
            for item in metadataItems {
                // Try common key
                if item.commonKey?.rawValue == "trackNumber" {
                    if let number = try? await item.load(.numberValue) {
                        metadata.trackNumber = number.intValue
                    } else if let str = try? await item.load(.stringValue), let num = Int(str) {
                        metadata.trackNumber = num
                    }
                }
                // Try ID3 track number identifier
                if let identifier = item.identifier?.rawValue,
                   identifier.contains("TRCK") || identifier.contains("trackNumber") {
                    if let number = try? await item.load(.numberValue) {
                        metadata.trackNumber = number.intValue
                    } else if let str = try? await item.load(.stringValue) {
                        // Handle "1/12" format
                        let parts = str.split(separator: "/")
                        if let first = parts.first, let num = Int(first) {
                            metadata.trackNumber = num
                        }
                    }
                }
            }
        }

        return metadata
    }
}
