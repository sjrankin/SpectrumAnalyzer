//
//  ContentView.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = ContentViewModel()

    var body: some View {
        VStack {
            ImageOutputView(image: viewModel.displayImage) { data in
                await viewModel.loadImage(data: data)
            }
            .containerRelativeFrame(.vertical) { height, _ in height * 0.5 }

            VStack {
                SpectrumView(frequencyBands: viewModel.audioEngine.frequencyBands)
                    .containerRelativeFrame(.vertical) { height, _ in height * 0.25 }
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    }
                    .padding(.horizontal)

                FrequencyLabelsView()

                Spacer()

                SourcePickerView(engine: viewModel.audioEngine)

                RecordButton(isRunning: viewModel.audioEngine.isRunning) {
                    Task { await viewModel.toggleAudio() }
                }
                .padding(.horizontal)

                RecordingStatusView(isRunning: viewModel.audioEngine.isRunning)
                    .padding(.bottom)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.black, .blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task(id: viewModel.audioEngine.isRunning) {
            await viewModel.runImageUpdates()
        }
        .alert("Error", isPresented: $viewModel.isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
    }
}

#Preview {
    ContentView()
}
