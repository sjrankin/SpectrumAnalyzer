//
//  SpectrumView.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import SwiftUI

struct SpectrumView: View {
    let frequencyBands: [Float]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(frequencyBands.enumerated(), id: \.offset) { index, value in
                // Bands are already dB-normalized to 0...1, so no extra gain.
                let amplified = min(1, CGFloat(value))
                let color = color(forBand: index, amplitude: amplified)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .containerRelativeFrame(.vertical) { height, _ in
                        max(10, amplified * height)
                    }
                    .shadow(color: color.opacity(0.5), radius: 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.black.gradient)
        .animation(.easeOut(duration: 0.05), value: frequencyBands)
    }

    private func color(forBand index: Int, amplitude: CGFloat) -> Color {
        let hue = Double(index) / Double(max(1, frequencyBands.count))
        return Color(hue: hue, saturation: 0.9, brightness: 0.4 + Double(amplitude) * 0.6)
    }
}

#Preview {
    SpectrumView(frequencyBands: Array(repeating: 0.05, count: 64))
        .frame(height: 300)
}
