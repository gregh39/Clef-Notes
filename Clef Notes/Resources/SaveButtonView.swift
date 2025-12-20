//
//  SaveButtonView.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/30/25.
//


import SwiftUI

struct SaveButtonView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    //.background(isDisabled ? Color.gray : settingsManager.activeAccentColor)
                    .foregroundColor(.white)
            }
            .glassEffect(.clear.tint(isDisabled ? Color.gray : settingsManager.activeAccentColor))
            .disabled(isDisabled)
            .padding()
        } else {
            Button(action: action) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isDisabled ? Color.gray : settingsManager.activeAccentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isDisabled)
            .padding()
        }
    }
}

struct PageButtonView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    let title: String
    let action: () -> Void
    var isSelected: Bool = false

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Text(title)
                    .fontWeight(.bold)
                    .padding()
                    .foregroundColor(.white)
            }
            .glassEffect(.clear.tint(isSelected ? Color.gray : settingsManager.activeAccentColor).interactive())
            .disabled(isSelected)
            .padding()
        }
    }
}
