//
//  SongRowView.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/1/25.
//
import SwiftUI
import SwiftData

// MARK: - Enhanced Song Row View
struct SongRowView: View {
    let song: Song
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if song.songStatus == .practice {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    
                    Text(song.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(song.totalGoalPlayCount)/\(song.goalPlays ?? 0)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: progress)))
                    .scaleEffect(y: 1.5)
            } else {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    Text(song.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func progressColor(for progress: Double) -> Color {
        switch progress {
        case 0..<0.3:
            return .red
        case 0.3..<0.7:
            return .orange
        case 0.7..<1.0:
            return .yellow
        default:
            return .green
        }
    }
}
