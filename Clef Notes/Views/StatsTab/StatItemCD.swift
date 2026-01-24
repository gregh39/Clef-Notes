//
//  StatItemCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI

struct StatItemCD: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .center) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .cornerRadius(10)
    }
}
