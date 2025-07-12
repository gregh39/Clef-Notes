//
//  PlayRow.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/11/25.
//
import SwiftUI
import Foundation

/// A private view component for displaying a single row in the plays list.
/// This makes the main `body` cleaner and separates concerns.
struct PlayRow: View {
    let play: Play

    var body: some View {
        HStack(alignment: .center) {
            // VStack for the song title and play type.
            VStack(alignment: .leading) {
                Text(play.song?.title ?? "Unknown Song")
                    .fontWeight(.medium) // Makes the title stand out.
                Text(play.playType?.rawValue ?? "Unknown Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // The count, displayed prominently on the right.
            Text("\(play.song?.cumulativeTypeCount(for: play) ?? play.count)")
                .font(.callout)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 2) // Adds a bit of vertical space for better readability.
    }
}

#Preview {
    PlayRow(play: Play(
        count: 5
    ))
}
