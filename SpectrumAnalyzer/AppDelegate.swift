//
//  AppDelegate.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Quit when the window is closed instead of lingering in the Dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
