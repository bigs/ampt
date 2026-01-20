//
//  SpiralIconGenerator.swift
//  ampt
//
//  Generates squared spiral icons with progressive fill for dock icon animation
//

import AppKit
import CoreGraphics

final class SpiralIconGenerator {

    // MARK: - Configuration

    private struct Config {
        let spacing: CGFloat
        let lineWidth: CGFloat
        let cornerRadius: CGFloat
        let turns: Int
        let margin: CGFloat

        init(forSize size: CGFloat) {
            // Define base geometry at 32x32, then scale proportionally
            let referenceSize: CGFloat = 32.0
            let referenceSpacing: CGFloat = 4.0
            let referenceLineWidth: CGFloat = 2.0
            let referenceCornerRadius: CGFloat = 1.0
            let referenceMargin: CGFloat = 3.2 // 10% of 32

            // Calculate scale factor
            let scale = size / referenceSize

            // Scale all parameters proportionally
            spacing = referenceSpacing * scale
            lineWidth = referenceLineWidth * scale
            cornerRadius = referenceCornerRadius * scale
            margin = referenceMargin * scale

            // Constant number of turns
            turns = 15
        }
    }

    // MARK: - Colors

    private let backgroundColor = NSColor(white: 0.95, alpha: 1.0)
    private let spiralColor = NSColor(white: 0.2, alpha: 0.8)
    private let progressColor = NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) // #FF9900

    // MARK: - Public API

    /// Generate an icon with optional progress fill (0.0 to 1.0)
    func generateIcon(size: CGSize, progress: Double = 0.0) -> NSImage {
        // Create bitmap representation at exact pixel size
        let pixelWidth = Int(size.width)
        let pixelHeight = Int(size.height)

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size)
        }

        // Set the bitmap size to match pixel dimensions (1:1 scale)
        bitmapRep.size = size

        // Draw into the bitmap context
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

        // Draw background
        backgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        // Generate spiral path
        let config = Config(forSize: size.width)
        let (spiralPath, pathLength) = generateSpiralPath(in: size, config: config)

        // Draw base spiral
        spiralColor.setStroke()
        let basePath = NSBezierPath(cgPath: spiralPath)
        basePath.lineWidth = config.lineWidth
        basePath.lineCapStyle = .round
        basePath.lineJoinStyle = .round
        basePath.stroke()

        // Draw progress fill if needed
        // Skip very small progress values to avoid rendering artifacts
        if progress > 0.005 {
            progressColor.setStroke()

            let fillLength = pathLength * CGFloat(progress)
            let progressPath = createProgressPath(from: spiralPath, length: fillLength, totalLength: pathLength, lineWidth: config.lineWidth)

            let fillBezier = NSBezierPath(cgPath: progressPath)
            fillBezier.lineWidth = config.lineWidth
            fillBezier.lineCapStyle = .round
            fillBezier.lineJoinStyle = .round
            fillBezier.stroke()
        }

        NSGraphicsContext.restoreGraphicsState()

        // Create NSImage from bitmap
        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)
        return image
    }

    // MARK: - Spiral Path Generation

    private func generateSpiralPath(in size: CGSize, config: Config) -> (path: CGPath, length: CGFloat) {
        let path = CGMutablePath()
        let rect = NSRect(origin: .zero, size: size)
        let drawRect = rect.insetBy(dx: config.margin, dy: config.margin)

        // Start from top-right corner
        var x = drawRect.maxX
        var y = drawRect.maxY
        path.move(to: CGPoint(x: x, y: y))

        var totalLength: CGFloat = 0

        // Draw squared spiral inward from top-right
        // Pattern: left → down → right → up (then repeat inward)
        for turn in 0..<config.turns {
            let inset = CGFloat(turn) * config.spacing

            // Left (along top edge)
            let leftX = drawRect.minX + inset
            if leftX <= x {
                totalLength += addLineWithRoundedCorner(
                    to: path,
                    from: CGPoint(x: x, y: y),
                    to: CGPoint(x: leftX, y: y),
                    cornerRadius: config.cornerRadius
                )
                x = leftX
            }

            // Down (along left edge)
            let downY = drawRect.minY + inset
            if downY <= y {
                totalLength += addLineWithRoundedCorner(
                    to: path,
                    from: CGPoint(x: x, y: y),
                    to: CGPoint(x: x, y: downY),
                    cornerRadius: config.cornerRadius
                )
                y = downY
            }

            // Right (along bottom edge)
            let rightX = drawRect.maxX - inset - config.spacing
            if rightX >= x {
                totalLength += addLineWithRoundedCorner(
                    to: path,
                    from: CGPoint(x: x, y: y),
                    to: CGPoint(x: rightX, y: y),
                    cornerRadius: config.cornerRadius
                )
                x = rightX
            }

            // Up (along right edge)
            let upY = drawRect.maxY - inset - config.spacing
            if upY >= y {
                totalLength += addLineWithRoundedCorner(
                    to: path,
                    from: CGPoint(x: x, y: y),
                    to: CGPoint(x: x, y: upY),
                    cornerRadius: config.cornerRadius
                )
                y = upY
            }
        }

        return (path.copy()!, totalLength)
    }

    private func addLineWithRoundedCorner(
        to path: CGMutablePath,
        from start: CGPoint,
        to end: CGPoint,
        cornerRadius: CGFloat
    ) -> CGFloat {
        // For simplicity, just add straight line
        // Corner rounding handled by line join style
        path.addLine(to: end)

        // Calculate distance
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Progress Path

    private func createProgressPath(from path: CGPath, length: CGFloat, totalLength: CGFloat, lineWidth: CGFloat) -> CGPath {
        // Create a partial path using dash pattern
        // This shows only the first 'length' of the path
        if length >= totalLength {
            return path
        }

        // Shorten the dash length by the line width to account for the round cap at the end
        // This prevents the end cap from appearing at the wrong position (center of spiral)
        let adjustedLength = max(length - lineWidth, 0)
        let dashPattern: [CGFloat] = [adjustedLength, totalLength - adjustedLength]
        return path.copy(dashingWithPhase: 0, lengths: dashPattern)
    }

    // MARK: - Static Icon Generation

    /// Generate all required static icon sizes for AppIcon.appiconset
    func generateStaticIcons(outputDirectory: String) throws {
        let sizes: [(name: String, size: CGFloat)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]

        let fileManager = FileManager.default

        // Ensure output directory exists
        if !fileManager.fileExists(atPath: outputDirectory) {
            try fileManager.createDirectory(
                atPath: outputDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Generate each icon
        for (filename, size) in sizes {
            let iconSize = CGSize(width: size, height: size)
            let image = generateIcon(size: iconSize, progress: 0.0) // No fill for static icons

            // Convert to PNG data
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let pngData = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
                throw NSError(domain: "SpiralIconGenerator", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to generate PNG for \(filename)"
                ])
            }

            // Write to file
            let outputPath = (outputDirectory as NSString).appendingPathComponent(filename)
            try pngData.write(to: URL(fileURLWithPath: outputPath))

            print("Generated: \(filename) (\(Int(size))×\(Int(size)))")
        }
    }
}
