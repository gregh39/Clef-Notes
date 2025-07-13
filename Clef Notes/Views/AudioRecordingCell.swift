import SwiftUI
import AVFoundation
import SwiftData
import Combine
import UniformTypeIdentifiers // Needed for the share sheet content type

// A helper struct to make the audio data transferable for the ShareLink.
private struct AudioFile: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        // Define how the data should be represented for sharing.
        DataRepresentation(contentType: .mpeg4Audio) { audio in
            // Provide the raw data when an export is requested.
            audio.data
        } importing: { data in
            // This part is required by the protocol but not used for sharing.
            AudioFile(data: data, filename: "imported.m4a")
        }
        // Provide a suggested filename for the share sheet.
        .suggestedFileName { audio in
            audio.filename
        }
    }
}


struct AudioRecordingCell: View {
    let recording: AudioRecording
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    let onDelete: (() -> Void)?
    
    @State private var isScrubbing = false
    
    var isPlaying: Bool {
        audioPlayerManager.currentlyPlayingID == recording.persistentModelID && audioPlayerManager.audioPlayer?.isPlaying == true
    }
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(recording.title ?? "Unknown Recording")
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
                
                // --- THIS IS THE FIX ---
                // This button will only appear if the recording has data.
                if let audioData = recording.data {
                    // Use the ShareLink initializer with a SharePreview for better stability.
                    ShareLink(
                        item: AudioFile(
                            data: audioData,
                            filename: "\(recording.title ?? "Recording").m4a"
                        ),
                        preview: SharePreview(
                            recording.title ?? "Audio Recording",
                            image: Image(systemName: "waveform") // Provide a generic icon for the preview.
                        )
                    ) {
                        // This is the label for the button itself.
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.accentColor)
                    }
                }
                
                // Play/Stop Button
                Button(action: {
                    if isPlaying {
                        audioPlayerManager.stop()
                    } else if let audioData = recording.data {
                        audioPlayerManager.play(data: audioData, id: recording.persistentModelID)
                    } else {
                        print("Cannot play: audio data is nil")
                    }
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
            
            // The playback scrubber, which only appears when playing.
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
}
