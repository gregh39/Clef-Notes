//
//  StreakItemCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//

import SwiftUI

struct StreakItemCD: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.title2)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(5)
        .cornerRadius(10)
    }
}
