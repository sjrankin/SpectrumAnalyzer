//
//  AudioEngineError.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import Foundation

enum AudioEngineError: LocalizedError {
    case permissionDenied
    case invalidFormat
    case analyzerUnavailable
    case audioSessionFailed(Error)
    case engineStartFailed(Error)
    case musicUnsupported
    case musicNotRunning
    case musicNotPlaying
    case captureFailed(step: String, status: Int32)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone access denied. Please enable it in Settings."
        case .invalidFormat:
            "Invalid audio format received from input device."
        case .analyzerUnavailable:
            "Could not set up the spectrum analyzer."
        case .audioSessionFailed(let error):
            "Failed to configure audio session: \(error.localizedDescription)"
        case .engineStartFailed(let error):
            "Failed to start audio engine: \(error.localizedDescription)"
        case .musicUnsupported:
            "Capturing Music playback is only available on macOS."
        case .musicNotRunning:
            "The Music app isn't running. Open Music and start playing something."
        case .musicNotPlaying:
            "Music isn't producing audio yet. Start playback in Music, then try again."
        case .captureFailed(let step, let status):
            "Could not capture Music audio (\(step) failed, error \(status)). Check that audio capture is allowed in System Settings > Privacy & Security."
        }
    }
}
