//
//  FrequencyLabelsView.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

import SwiftUI

struct FrequencyLabelsView: View {
    var body: some View {
        HStack {
            Text("Low")
            Spacer()
            Text("Mid")
            Spacer()
            Text("High")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }
}

#Preview {
    FrequencyLabelsView()
}
