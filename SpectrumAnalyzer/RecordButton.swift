//
//  RecordButton.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import SwiftUI

struct RecordButton: View {
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isRunning ? "Stop" : "Start",
                systemImage: isRunning ? "stop.circle.fill" : "play.circle.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            .background(isRunning ? .red : .green)
            .foregroundStyle(.white)
            .clipShape(.rect(cornerRadius: 12))
            .shadow(radius: 5)
        }
    }
}

#Preview {
    RecordButton(isRunning: false) { }
}
