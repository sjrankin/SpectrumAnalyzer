//
//  SourcePickerView.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import SwiftUI

struct SourcePickerView: View {
    @Bindable var engine: AudioEngine

    var body: some View {
        if AudioSource.available.count > 1 {
            Picker("Input", selection: $engine.source) {
                ForEach(AudioSource.available) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .disabled(engine.isRunning)
            .padding(.horizontal)
        }
    }
}
