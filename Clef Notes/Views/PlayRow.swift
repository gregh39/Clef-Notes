//
//  PlayRow.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/11/25.
//
import SwiftUI
import Foundation

struct PlayRow: View {
    let play: Play
    
    // --- NEW: Add a property to receive the pre-calculated total ---
    let cumulativeTotal: Int

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text(play.song?.title ?? "Unknown Song")
                    .fontWeight(.medium)
                Text(play.playType?.rawValue ?? "Unknown Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // --- MODIFIED: Directly display the passed-in total ---
            Text("\(cumulativeTotal)")
                .font(.callout)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PlayRow(play: Play(count: 5), cumulativeTotal: 15)
}
