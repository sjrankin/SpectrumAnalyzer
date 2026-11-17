//
//  SpectrumDSP.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import AVFoundation
import Accelerate

/// Converts audio buffers into smoothed, normalized frequency bands.
///
/// All work happens on the audio render thread, so this type is deliberately
/// not main-actor isolated. Scratch buffers are allocated once up front, and
/// the smoothing state lives here rather than being shared with the UI.
nonisolated final class SpectrumDSP: @unchecked Sendable {
    let bandCount: Int
    private let fftSize: Int
    private let binCount: Int
    private let dftSetup: vDSP_DFT_Setup

    private let window: [Float]
    private var realIn: [Float]
    private var imagIn: [Float]
    private var realOut: [Float]
    private var imagOut: [Float]
    private var magnitudes: [Float]
    private var smoothedBands: [Float]

    /// Inclusive start / exclusive end FFT-bin ranges for each band; never empty.
    private let bandRanges: [Range<Int>]

    private let minDB: Float = -80
    private let maxDB: Float = 0
    private let smoothingFactor: Float = 0.3

    init?(fftSize: Int = 1024, bandCount: Int = 64) {
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) else {
            return nil
        }
        self.dftSetup = setup
        self.fftSize = fftSize
        self.bandCount = bandCount
        self.binCount = fftSize / 2

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = window

        realIn = [Float](repeating: 0, count: fftSize)
        imagIn = [Float](repeating: 0, count: fftSize)
        realOut = [Float](repeating: 0, count: fftSize)
        imagOut = [Float](repeating: 0, count: fftSize)
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
        smoothedBands = [Float](repeating: 0, count: bandCount)

        // Quadratic spacing, with every band guaranteed at least one bin.
        let bins = fftSize / 2
        bandRanges = (0..<bandCount).map { index in
            let lower = Float(index) / Float(bandCount)
            let upper = Float(index + 1) / Float(bandCount)
            let start = min(bins - 1, Int(lower * lower * Float(bins)))
            let end = min(bins, max(start + 1, Int(upper * upper * Float(bins))))
            return start..<end
        }
    }

    deinit {
        vDSP_DFT_DestroySetup(dftSetup)
    }

    /// Processes one buffer and returns the updated bands (each 0...1).
    func process(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        return process(samples: channelData, count: Int(buffer.frameLength), stride: buffer.stride)
    }

    /// Processes `count` frames of float samples, reading every `stride`-th
    /// value (so interleaved multichannel data can use its first channel).
    func process(samples: UnsafePointer<Float>, count: Int, stride: Int) -> [Float]? {
        let sampleCount = min(count, fftSize)
        guard sampleCount > 0, stride > 0 else { return nil }

        // Window the samples; zero-pad if the buffer is shorter than the FFT.
        realIn.withUnsafeMutableBufferPointer { pointer in
            vDSP_vmul(samples, vDSP_Stride(stride), window, 1, pointer.baseAddress!, 1, vDSP_Length(sampleCount))
            if sampleCount < fftSize {
                for index in sampleCount..<fftSize { pointer[index] = 0 }
            }
        }

        vDSP_DFT_Execute(dftSetup, realIn, imagIn, &realOut, &imagOut)

        realOut.withUnsafeMutableBufferPointer { realPointer in
            imagOut.withUnsafeMutableBufferPointer { imagPointer in
                var complex = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(binCount))
            }
        }

        // Normalize by FFT length.
        var scale = 1 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(binCount))

        for (index, range) in bandRanges.enumerated() {
            var sum: Float = 0
            magnitudes.withUnsafeBufferPointer { pointer in
                vDSP_sve(pointer.baseAddress! + range.lowerBound, 1, &sum, vDSP_Length(range.count))
            }
            let average = sum / Float(range.count)
            let decibels = 20 * log10(max(average, 0.000001))
            let normalized = (max(minDB, min(maxDB, decibels)) - minDB) / (maxDB - minDB)
            smoothedBands[index] = smoothingFactor * normalized + (1 - smoothingFactor) * smoothedBands[index]
        }
        return smoothedBands
    }
}
