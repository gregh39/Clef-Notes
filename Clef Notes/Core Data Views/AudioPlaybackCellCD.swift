import SwiftUI
import CoreData
import AVFoundation
import UniformTypeIdentifiers

// A helper struct to make audio data transferable for the ShareLink.
private struct AudioFile: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .mpeg4Audio) { audio in
            audio.data
        } importing: { data in
            // This part is required by the protocol but not used for sharing.
            AudioFile(data: data, filename: "imported.m4a")
        }
        .suggestedFileName { audio in
            audio.filename
        }
    }
}

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
                    if duration > 0 {
                        Text("Duration: \(Int(duration))s").font(.caption2).foregroundColor(.gray)
                    }
                }
                Spacer()
                
                HStack(spacing: 16) {
                    // --- THIS IS THE FIX ---
                    // The ShareLink is now included, matching the original version.
                    if let audioData = data {
                        ShareLink(
                            item: AudioFile(data: audioData, filename: "\(title).m4a"),
                            preview: SharePreview(title, image: Image(systemName: "waveform"))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(Circle())
                        }
                    }
                    
                    Button(action: {
                        if isPlaying {
                            audioPlayerManager.stop()
                        } else if let audioData = data {
                            audioPlayerManager.play(data: audioData, id: id)
                        }
                    }) {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(Circle())
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
