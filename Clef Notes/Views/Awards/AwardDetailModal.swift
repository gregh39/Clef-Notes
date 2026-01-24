//
//  AwardDetailModal.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI

struct AwardDetailModal: View {
    let award: Award
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: award.icon)
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text(award.rawValue)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(award.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Close") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top)
        }
        .padding(30)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10)
        .padding(40)
    }
}
