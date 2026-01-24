//
//  SongCardView.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI

struct SongCardView: View {
    @ObservedObject var song: SongCD
    
    private var progress: Double {
        guard let goal = song.goalPlays > 0 ? Double(song.goalPlays) : nil else { return 0.0 }
        let total = Double(song.totalGoalPlayCount)
        return min(total / goal, 1.0)
    }
    
    private var statusColor: Color {
        switch song.songStatus {
        case .learning: .blue
        case .practice: .green
        case .review: .purple
        case .none: .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(song.title ?? "Unknown Song")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let status = song.songStatus {
                    Text(status.rawValue.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            if song.songStatus == .practice {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
                    
                    HStack {
                        Text("Goal")
                        Spacer()
                        Text("\(song.totalGoalPlayCount) / \(song.goalPlays) Plays")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

