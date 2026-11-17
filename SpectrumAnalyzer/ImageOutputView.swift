//
//  ImageOutputView.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/21/26.
//

import SwiftUI
import PhotosUI

struct ImageOutputView: View {
    let image: CGImage?
    let onImageDataLoaded: (Data) async -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingPhotoPicker = false

    var body: some View {
        VStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "waveform.slash")
                    .resizable()
                    .scaledToFit()
            }

            Button("Load Image", systemImage: "photo") {
                isShowingPhotoPicker = true
            }
            .buttonStyle(.glassProminent)
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) {
            guard let item = selectedItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await onImageDataLoaded(data)
                }
            }
        }
    }
}

#Preview {
    ImageOutputView(image: nil) { _ in }
}
