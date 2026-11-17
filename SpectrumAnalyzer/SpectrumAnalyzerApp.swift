//
//  SpectrumAnalyzerApp.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import SwiftUI

@main
struct SpectrumAnalyzerApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
