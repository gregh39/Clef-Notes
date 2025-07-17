//
//  AudioPlaybackCellCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/16/25.
//


import SwiftUI
import CoreData
import AVFoundation

struct AudioPlaybackCellCD: View {
    let title: String
    let subtitle: String
    let data: Data?
    let duration: Double
    let id: NSManagedObjectID
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    
    @State private var isScrubbing = false
    
    var isPlaying: Bool {
        audioPlayerManager.currentlyPlayingID == id && audioPlayerManager.audioPlayer?.isPlaying == true
    }
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                    Text("Duration: \(Int(duration))s").font(.caption2).foregroundColor(.gray)
                }
                Spacer()
                
                HStack(spacing: 16) {
                    // ShareLink would be added here
                    Button(action: {
                        if isPlaying {
                            audioPlayerManager.stop()
                        } else if let audioData = data {
                            audioPlayerManager.play(data: audioData, id: id)
                        }
                    }) {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    }
                    .disabled(data == nil)
                }
                .buttonStyle(.plain)
            }
            
            if isPlaying {
                Slider(
                    value: Binding(
                        get: { isScrubbing ? audioPlayerManager.currentTime : min(audioPlayerManager.currentTime, duration) },
                        set: { isScrubbing = true; audioPlayerManager.currentTime = $0 }
                    ),
                    in: 0...duration,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            audioPlayerManager.seek(to: audioPlayerManager.currentTime)
                        }
                    }
                )
                HStack {
                    Text(String(format: "%02d:%02d", Int(audioPlayerManager.currentTime) / 60, Int(audioPlayerManager.currentTime) % 60))
                    Spacer()
                    Text(String(format: "%02d:%02d", Int(duration) / 60, Int(duration) % 60))
                }
                .font(.caption2).foregroundColor(.gray)
            }
        }
    }
}
