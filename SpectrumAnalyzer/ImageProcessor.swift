//
//  ImageProcessor.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/21/26.
//

import CoreGraphics
import Foundation
import ImageIO

/// Prepares images once and tints them per frame from spectrum data.
nonisolated enum ImageProcessor {
    private static let maxDimension = 800

    /// Decodes image data, fixes orientation and downsamples in one ImageIO pass
    /// (works on both iOS and macOS). Do this once when an image is loaded,
    /// not on every frame.
    @concurrent
    static func prepare(data: Data) async -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Scales the red, green and blue channels by the low, mid and high
    /// thirds of the spectrum (0...1 bands, up to 11x gain).
    @concurrent
    static func applySpectrum(to cgImage: CGImage, frequencyBands: [Float]) async -> CGImage? {
        guard frequencyBands.count >= 3 else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = 4 * width

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = context.data else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let third = frequencyBands.count / 3
        let low = average(frequencyBands[0..<third])
        let mid = average(frequencyBands[third..<2 * third])
        let high = average(frequencyBands[2 * third..<frequencyBands.count])

        let redTable = gainTable(1 + low * 10)
        let greenTable = gainTable(1 + mid * 10)
        let blueTable = gainTable(1 + high * 10)

        let pixels = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
        for offset in stride(from: 0, to: bytesPerRow * height, by: 4) {
            let alpha = pixels[offset + 3]
            // Premultiplied color can never exceed alpha.
            pixels[offset] = min(alpha, redTable[Int(pixels[offset])])
            pixels[offset + 1] = min(alpha, greenTable[Int(pixels[offset + 1])])
            pixels[offset + 2] = min(alpha, blueTable[Int(pixels[offset + 2])])
        }
        return context.makeImage()
    }

    private static func average(_ values: ArraySlice<Float>) -> Float {
        guard !values.isEmpty else { return 0 }
        let safe = values.map { $0.isFinite ? $0 : 0 }
        return safe.reduce(0, +) / Float(safe.count)
    }

    /// A 256-entry lookup table: one multiply per level instead of per pixel.
    private static func gainTable(_ gain: Float) -> [UInt8] {
        (0..<256).map { UInt8(max(0, min(255, Float($0) * gain))) }
    }
}
