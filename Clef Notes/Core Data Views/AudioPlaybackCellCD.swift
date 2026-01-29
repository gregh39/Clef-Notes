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
    @State private var showSpeedControl = false

    var isPlaying: Bool {
        audioPlayerManager.currentlyPlayingID == id && audioPlayerManager.isPlaying
    }

    var effectiveDuration: Double {
        // Use stored duration if available, otherwise get from player
        if duration > 0 {
            return duration
        } else if audioPlayerManager.currentlyPlayingID == id, audioPlayerManager.duration > 0 {
            return audioPlayerManager.duration
        }
        return 0
    }

    var body: some View {
        VStack(spacing: 12) {
            // Title and share button
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                    if effectiveDuration > 0 {
                        Text("Duration: \(formatDuration(effectiveDuration))").font(.caption2).foregroundColor(.gray)
                    }
                }
                Spacer()

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
            }

            // Playback controls - always visible when playing
            if isPlaying || audioPlayerManager.currentlyPlayingID == id {
                VStack(spacing: 8) {
                    // Seek slider
                    Slider(
                        value: Binding(
                            get: { isScrubbing ? audioPlayerManager.currentTime : min(audioPlayerManager.currentTime, effectiveDuration) },
                            set: { isScrubbing = true; audioPlayerManager.currentTime = $0 }
                        ),
                        in: 0...max(effectiveDuration, 1),
                        onEditingChanged: { editing in
                            isScrubbing = editing
                            if !editing {
                                audioPlayerManager.seek(to: audioPlayerManager.currentTime)
                            }
                        }
                    )

                    // Time display
                    HStack {
                        Text(formatDuration(audioPlayerManager.currentTime))
                        Spacer()
                        Text(formatDuration(effectiveDuration))
                    }
                    .font(.caption2).foregroundColor(.gray)

                    // Main playback controls
                    HStack(spacing: 20) {
                        // Skip back button
                        Button(action: {
                            audioPlayerManager.skipBackward()
                        }) {
                            Image(systemName: "gobackward.5")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!isPlaying && audioPlayerManager.currentlyPlayingID != id)

                        // Play/Pause button
                        Button(action: {
                            if audioPlayerManager.currentlyPlayingID == id {
                                audioPlayerManager.togglePlayPause()
                            } else if let audioData = data {
                                audioPlayerManager.play(data: audioData, id: id)
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .frame(width: 50, height: 50)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .disabled(data == nil)

                        // Skip forward button
                        Button(action: {
                            audioPlayerManager.skipForward()
                        }) {
                            Image(systemName: "goforward.5")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!isPlaying && audioPlayerManager.currentlyPlayingID != id)

                        // Stop button
                        Button(action: {
                            audioPlayerManager.stop()
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(audioPlayerManager.currentlyPlayingID != id)

                        // Speed control button
                        Button(action: {
                            showSpeedControl.toggle()
                        }) {
                            HStack(spacing: 2) {
                                Text("\(audioPlayerManager.playbackRate, specifier: "%.1f")")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("×")
                                    .font(.caption2)
                            }
                            .frame(width: 44, height: 44)
                            .background(showSpeedControl ? Color.accentColor : Color(UIColor.systemGray5))
                            .foregroundColor(showSpeedControl ? .white : .primary)
                            .clipShape(Circle())
                        }
                    }
                    .buttonStyle(.plain)

                    // Speed control picker (shown when button tapped)
                    if showSpeedControl {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Playback Speed")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                                    Button(action: {
                                        audioPlayerManager.setPlaybackRate(Float(speed))
                                    }) {
                                        Text("\(speed, specifier: "%.2f")×")
                                            .font(.caption)
                                            .fontWeight(audioPlayerManager.playbackRate == Float(speed) ? .bold : .regular)
                                            .foregroundColor(audioPlayerManager.playbackRate == Float(speed) ? .white : .primary)
                                            .frame(minWidth: 50)
                                            .padding(.vertical, 6)
                                            .background(audioPlayerManager.playbackRate == Float(speed) ? Color.accentColor : Color(UIColor.systemGray6))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .transition(.opacity)
                    }
                }
            } else {
                // Simple play button when not playing
                HStack {
                    Spacer()
                    Button(action: {
                        if let audioData = data {
                            audioPlayerManager.play(data: audioData, id: id)
                        }
                    }) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(Circle())
                    }
                    .disabled(data == nil)
                    .buttonStyle(.plain)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .animation(.easeInOut(duration: 0.2), value: showSpeedControl)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
