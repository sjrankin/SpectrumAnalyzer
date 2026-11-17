//
//  ContentViewModel.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import CoreGraphics
import Foundation

@MainActor
@Observable
final class ContentViewModel {
    let audioEngine = AudioEngine()

    private(set) var displayImage: CGImage?
    var errorMessage: String?
    var isShowingError = false

    private var baseImage: CGImage?
    private let frameInterval = Duration.milliseconds(66) // ~15 FPS

    func loadImage(data: Data) async {
        guard let prepared = await ImageProcessor.prepare(data: data) else { return }
        baseImage = prepared
        displayImage = prepared
    }

    func toggleAudio() async {
        if audioEngine.isRunning {
            audioEngine.stop()
            return
        }
        do {
            try await audioEngine.start()
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }

    /// Runs while audio is capturing; cancelled automatically when it stops.
    /// Frames are processed one at a time, so work can never queue up.
    func runImageUpdates() async {
        guard audioEngine.isRunning else {
            displayImage = baseImage
            return
        }
        while !Task.isCancelled {
            await refreshImage()
            try? await Task.sleep(for: frameInterval)
        }
    }

    private func refreshImage() async {
        guard let baseImage else { return }
        let bands = audioEngine.frequencyBands
        guard let processed = await ImageProcessor.applySpectrum(to: baseImage, frequencyBands: bands),
              !Task.isCancelled else { return }
        displayImage = processed
    }
}
