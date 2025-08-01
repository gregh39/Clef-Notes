//
//  SaveButtonView.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/30/25.
//


import SwiftUI

struct SaveButtonView: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDisabled ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .disabled(isDisabled)
        .padding()
    }
}
