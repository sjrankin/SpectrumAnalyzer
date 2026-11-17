//
//  AudioEngine.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import AVFoundation

@MainActor
@Observable
final class AudioEngine {
    private let engine = AVAudioEngine()
    private let dsp = SpectrumDSP()
    #if os(macOS)
    private let musicTap = MusicAudioTap()
    #endif

    private(set) var frequencyBands: [Float] = Array(repeating: 0, count: 64)
    private(set) var isRunning = false
    private var activeSource: AudioSource?

    /// The input to analyze. Change it only while stopped.
    var source: AudioSource = .microphone

    func start() async throws {
        guard !isRunning else { return }
        guard let dsp else { throw AudioEngineError.analyzerUnavailable }

        let source = source
        switch source {
        case .microphone:
            try await startMicrophone(dsp: dsp)
        case .music:
            try startMusic(dsp: dsp)
        }
        activeSource = source
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        switch activeSource {
        case .microphone:
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        case .music:
            #if os(macOS)
            musicTap.stop()
            #endif
        case nil:
            break
        }
        activeSource = nil
        isRunning = false
        frequencyBands = Array(repeating: 0, count: frequencyBands.count)
    }

    // MARK: - Sources

    private func startMicrophone(dsp: SpectrumDSP) async throws {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw AudioEngineError.permissionDenied
        }

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
        } catch {
            throw AudioEngineError.audioSessionFailed(error)
        }
        #endif

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioEngineError.invalidFormat
        }

        // The tap runs on the audio thread, so it is built in a nonisolated
        // context and hops back to the main actor only to publish results.
        let handler = Self.makeTapHandler(dsp: dsp, publish: makePublisher())
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: handler)

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioEngineError.engineStartFailed(error)
        }
    }

    private func startMusic(dsp: SpectrumDSP) throws {
        #if os(macOS)
        try musicTap.start(dsp: dsp, publish: makePublisher())
        #else
        throw AudioEngineError.musicUnsupported
        #endif
    }

    /// A callback that is safe to call from any thread and publishes on the main actor.
    private func makePublisher() -> @Sendable ([Float]) -> Void {
        { [weak self] bands in
            Task { @MainActor [weak self] in
                self?.frequencyBands = bands
            }
        }
    }

    private nonisolated static func makeTapHandler(
        dsp: SpectrumDSP,
        publish: @escaping @Sendable ([Float]) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            if let bands = dsp.process(buffer) {
                publish(bands)
            }
        }
    }
}
