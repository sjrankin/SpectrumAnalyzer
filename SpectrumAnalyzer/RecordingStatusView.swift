//
//  RecordingStatusView.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import SwiftUI

struct RecordingStatusView: View {
    let isRunning: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(isRunning ? .green : .gray)
                .frame(width: 10, height: 10)
                .shadow(color: isRunning ? .green : .clear, radius: 5)

            Text(isRunning ? "Listening" : "Stopped")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RecordingStatusView(isRunning: true)
}
