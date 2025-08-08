//
//  SessionCardViewCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI

struct SessionCardViewCD: View {
    @ObservedObject var session: PracticeSessionCD
    
    private var totalPlays: Int {
        session.playsArray.reduce(0) { $0 + Int($1.count) }
    }
    private var noteCount: Int {
        session.notesArray.count
    }
    private var recordingCount: Int {
        session.recordingsArray.count
    }
    private var durationString: String {
        let totalMinutes = session.durationMinutes
        guard totalMinutes > 0 else { return "" }
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.title ?? "Practice").font(.headline).fontWeight(.bold)
                Spacer()
                Text((session.day ?? .now).formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                if let location = session.location {
                    HStack{
                        Image(systemName: "mappin.and.ellipse")
                        Text(location.rawValue)
                    }
                }
                Spacer()
                if let instructor = session.instructor {
                    HStack{
                        Image(systemName: "person.fill")
                        Text(instructor.name ?? "Unknown")
                    }
                }
            }
            .font(.subheadline).foregroundColor(.secondary)
            
            if totalPlays > 0 || noteCount > 0 || recordingCount > 0 || session.durationMinutes > 0 {
                Divider()
                HStack(spacing: 16) {
                    if totalPlays > 0 {
                        HStack{
                            Image(systemName: "music.note.list")
                            Text("\(totalPlays)")
                        }
                        .foregroundStyle(.blue)
                    }
                    if noteCount > 0 {
                        HStack{
                            Image(systemName: "note.text")
                            Text("\(noteCount)")
                        }
                        .foregroundStyle(.orange)
                    }
                    if recordingCount > 0 {
                        HStack{
                            Image(systemName: "mic.fill")
                            Text("\(recordingCount)")
                        }
                        .foregroundStyle(.red)
                    }
                    Spacer()
                    if session.durationMinutes > 0 {
                        HStack{
                            Image(systemName: "clock.fill")
                            Text("\(durationString)")
                        }
                        .foregroundStyle(.purple)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

