//
//  AudioSource.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import Foundation

/// Where the analyzer gets its audio from.
enum AudioSource: String, CaseIterable, Identifiable {
    case microphone
    case music

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone: "Microphone"
        case .music: "Music"
        }
    }

    /// Capturing another app's output is only possible on macOS.
    static var available: [AudioSource] {
        #if os(macOS)
        [.microphone, .music]
        #else
        [.microphone]
        #endif
    }
}
