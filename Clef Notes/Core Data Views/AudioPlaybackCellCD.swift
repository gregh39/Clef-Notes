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
        VStack(spacing: 10) {
            // Title and buttons row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                    if effectiveDuration > 0 {
                        Text(formatDuration(effectiveDuration)).font(.caption2).foregroundColor(.gray)
                    }
                }
                Spacer()

                // Buttons always on same row
                HStack(spacing: 12) {
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
                        .buttonStyle(.plain)
                    }

                    Button(action: {
                        if audioPlayerManager.currentlyPlayingID == id {
                            audioPlayerManager.togglePlayPause()
                        } else if let audioData = data {
                            audioPlayerManager.play(data: audioData, id: id)
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(isPlaying ? Color.accentColor : Color(UIColor.systemGray5))
                            .foregroundColor(isPlaying ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .disabled(data == nil)
                    .buttonStyle(.plain)
                }
            }

            // Playback controls - only when playing or loaded
            if isPlaying || audioPlayerManager.currentlyPlayingID == id {
                VStack(spacing: 6) {
                    // Seek slider and time
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

                    HStack {
                        Text(formatDuration(audioPlayerManager.currentTime))
                        Spacer()
                        Text(formatDuration(effectiveDuration))
                    }
                    .font(.caption2).foregroundColor(.gray)

                    // Control buttons row
                    HStack(spacing: 16) {
                        Button(action: { audioPlayerManager.skipBackward() }) {
                            Image(systemName: "gobackward.5")
                                .font(.body)
                                .frame(width: 36, height: 36)
                        }
                        .disabled(!isPlaying && audioPlayerManager.currentlyPlayingID != id)

                        Spacer()

                        Button(action: { audioPlayerManager.stop() }) {
                            Image(systemName: "stop.fill")
                                .font(.body)
                                .frame(width: 36, height: 36)
                        }
                        .disabled(audioPlayerManager.currentlyPlayingID != id)

                        Spacer()

                        Button(action: { audioPlayerManager.skipForward() }) {
                            Image(systemName: "goforward.5")
                                .font(.body)
                                .frame(width: 36, height: 36)
                        }
                        .disabled(!isPlaying && audioPlayerManager.currentlyPlayingID != id)

                        Spacer()

                        Button(action: { showSpeedControl.toggle() }) {
                            VStack(spacing: -2) {
                                Text("\(Int(audioPlayerManager.playbackRate * 100))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text("%")
                                    .font(.caption2)
                            }
                            .frame(width: 36, height: 36)
                            .background(showSpeedControl ? Color.accentColor : Color(UIColor.systemGray5))
                            .foregroundColor(showSpeedControl ? .white : .primary)
                            .clipShape(Circle())
                        }
                    }
                    .buttonStyle(.plain)

                    // Speed control slider
                    if showSpeedControl {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Speed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(audioPlayerManager.playbackRate * 100))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                            }

                            HStack(spacing: 8) {
                                Text("50")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Slider(
                                    value: Binding(
                                        get: { Double(audioPlayerManager.playbackRate) },
                                        set: { audioPlayerManager.setPlaybackRate(Float($0)) }
                                    ),
                                    in: 0.5...2.0,
                                    step: 0.01
                                )
                                .tint(.accentColor)

                                Text("200")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(UIColor.systemGray6).opacity(0.5))
                        .cornerRadius(8)
                        .transition(.opacity)
                    }
                }
                .padding(.top, 4)
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
