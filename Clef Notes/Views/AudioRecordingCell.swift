// AudioRecordingCell.swift
// Reusable cell for displaying and playing audio recordings.
import SwiftUI
import AVFoundation
import SwiftData
import Combine

struct AudioRecordingCell: View {
    let recording: AudioRecording
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    let onDelete: (() -> Void)?
    
    @State private var isScrubbing = false
    
    var isPlaying: Bool {
        audioPlayerManager.currentlyPlayingID == recording.persistentModelID && audioPlayerManager.audioPlayer?.isPlaying == true
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(recording.title ?? recording.fileURL?.lastPathComponent ?? "Unknown")
                    .font(.headline)
                Text(recording.dateRecorded.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let duration = recording.duration {
                    Text("Duration: \(Int(duration))s")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Button(action: {
                print("[AudioRecordingCell] Play button tapped for: \(String(describing: recording.fileURL))")
                if let fileURL = recording.fileURL {
                    print("File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
                } else {
                    print("File URL is nil")
                }
                print("isPlaying: \(isPlaying)")
                if isPlaying {
                    print("Stopping playback")
                    audioPlayerManager.stop()
                } else if let fileURL = recording.fileURL {
                    print("Starting playback")
                    audioPlayerManager.play(url: fileURL, id: recording.persistentModelID)
                } else {
                    print("Cannot play: fileURL is nil")
                }
            }) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
        if isPlaying, let duration = recording.duration {
            Slider(
                value: Binding(
                    get: { isScrubbing ? audioPlayerManager.currentTime : min(audioPlayerManager.currentTime, duration) },
                    set: { newValue in
                        isScrubbing = true
                        audioPlayerManager.currentTime = newValue
                    }
                ),
                in: 0...duration,
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing {
                        audioPlayerManager.seek(to: audioPlayerManager.currentTime)
                    }
                }
            )
            .accentColor(.accentColor)
            .padding(.horizontal, 8)
            HStack {
                Text(String(format: "%02d:%02d", Int(audioPlayerManager.currentTime) / 60, Int(audioPlayerManager.currentTime) % 60))
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%02d:%02d", Int(duration) / 60, Int(duration) % 60))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
        }
    }
}
 
