//
//  MetronomeSectionView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/13/25.
//
import SwiftUI

struct MetronomeSectionView: View {
    @Binding var isMetronomeOn: Bool
    @Binding var tempo: Double
    let toggleAction: (Bool) -> Void
    let tempoChanged: () -> Void

    var body: some View {
        Section("Metronome") {
            Toggle("Enable Metronome", isOn: $isMetronomeOn)
                .onChange(of: isMetronomeOn) { enabled in
                    toggleAction(enabled)
                }

            HStack {
                Text("Tempo: \(Int(tempo)) BPM")
                Slider(value: $tempo, in: 40...208, step: 1)
                    .onChange(of: tempo) { _ in
                        tempoChanged()
                    }
            }
        }
    }
}
