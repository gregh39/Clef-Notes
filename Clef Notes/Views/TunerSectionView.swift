//
//  TunerSectionView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/13/25.
//
import SwiftUI

struct TunerSectionView: View {
    @Binding var isTunerOn: Bool
    let toggleAction: (Bool) -> Void

    var body: some View {
        Section("Tuner") {
            Toggle("Play A 440", isOn: $isTunerOn)
                .onChange(of: isTunerOn) { newValue in
                    toggleAction(newValue)
                }
        }
    }
}
