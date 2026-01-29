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
        VStack(spacing: 0) {
            // Main content card
            VStack(spacing: 14) {
                // Header row
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if effectiveDuration > 0 {
                            Text(formatDuration(effectiveDuration))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()

                    // Action buttons
                    HStack(spacing: 10) {
                        if let audioData = data {
                            ShareLink(
                                item: AudioFile(data: audioData, filename: "\(title).m4a"),
                                preview: SharePreview(title, image: Image(systemName: "waveform"))
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial, in: Circle())
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
                                .font(.body)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: Circle()
                                )
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(data == nil)
                        .buttonStyle(.plain)
                    }
                }

                // Playback controls (when playing or loaded)
                if isPlaying || audioPlayerManager.currentlyPlayingID == id {
                    VStack(spacing: 12) {
                        // Seek slider with loop indicators
                        ZStack(alignment: .leading) {
                            // Loop region background
                            if let loopA = audioPlayerManager.loopA, let loopB = audioPlayerManager.loopB, effectiveDuration > 0 {
                                let startPercent = CGFloat(loopA / effectiveDuration)
                                let endPercent = CGFloat(loopB / effectiveDuration)

                                GeometryReader { geometry in
                                    Rectangle()
                                        .fill(Color.accentColor.opacity(0.15))
                                        .frame(width: geometry.size.width * (endPercent - startPercent))
                                        .offset(x: geometry.size.width * startPercent)
                                }
                                .frame(height: 4)
                            }

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
                            .tint(.accentColor)
                        }

                        // Time display
                        HStack {
                            Text(formatDuration(audioPlayerManager.currentTime))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                            Text(formatDuration(effectiveDuration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        // Control buttons in rounded container
                        HStack(spacing: 0) {
                            // Skip back
                            controlButton(icon: "gobackward.5") {
                                audioPlayerManager.skipBackward()
                            }
                            .disabled(!isPlaying && audioPlayerManager.currentlyPlayingID != id)

                            Divider()
                                .frame(height: 20)
                                .overlay(.separator.opacity(0.3))

                            // Stop
                            controlButton(icon: "stop.fill") {
                                audioPlayerManager.stop()
                            }
                            .disabled(audioPlayerManager.currentlyPlayingID != id)

                            Divider()
                                .frame(height: 20)
                                .overlay(.separator.opacity(0.3))

                            // Skip forward
                            controlButton(icon: "goforward.5") {
                                audioPlayerManager.skipForward()
                            }
                            .disabled(!isPlaying && audioPlayerManager.currentlyPlayingID != id)

                            Divider()
                                .frame(height: 20)
                                .overlay(.separator.opacity(0.3))

                            // Speed control
                            controlButton(icon: nil, label: "\(Int(audioPlayerManager.playbackRate * 100))%") {
                                withAnimation(.spring(response: 0.3)) {
                                    showSpeedControl.toggle()
                                }
                            }
                        }
                        .frame(height: 44)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.separator.opacity(0.2), lineWidth: 0.5)
                        )

                        // A-B Loop controls
                        HStack(spacing: 8) {
                            loopButton(
                                label: "A",
                                isSet: audioPlayerManager.loopA != nil,
                                time: audioPlayerManager.loopA
                            ) {
                                audioPlayerManager.setLoopA()
                            }

                            loopButton(
                                label: "B",
                                isSet: audioPlayerManager.loopB != nil,
                                time: audioPlayerManager.loopB
                            ) {
                                audioPlayerManager.setLoopB()
                            }

                            if audioPlayerManager.hasLoopPoints {
                                Button(action: {
                                    audioPlayerManager.toggleLoop()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: audioPlayerManager.isLooping ? "repeat.circle.fill" : "repeat.circle")
                                        Text("Loop")
                                            .font(.caption.weight(.medium))
                                    }
                                    .foregroundStyle(audioPlayerManager.isLooping ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(
                                        audioPlayerManager.isLooping ?
                                            AnyShapeStyle(Color.accentColor.gradient) :
                                            AnyShapeStyle(.thinMaterial)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(audioPlayerManager.isLooping ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    audioPlayerManager.clearLoop()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32, height: 32)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Speed control slider
                        if showSpeedControl {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Playback Speed")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(audioPlayerManager.playbackRate * 100))%")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .monospacedDigit()
                                }

                                HStack(spacing: 12) {
                                    Text("50")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .monospacedDigit()

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
                                        .foregroundStyle(.tertiary)
                                        .monospacedDigit()
                                }
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.separator.opacity(0.2), lineWidth: 0.5)
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.separator.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
        .animation(.spring(response: 0.3), value: isPlaying)
        .animation(.spring(response: 0.3), value: showSpeedControl)
        .animation(.spring(response: 0.3), value: audioPlayerManager.loopA)
        .animation(.spring(response: 0.3), value: audioPlayerManager.loopB)
        .animation(.spring(response: 0.3), value: audioPlayerManager.isLooping)
    }

    @ViewBuilder
    private func controlButton(icon: String? = nil, label: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body)
                } else if let label = label {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func loopButton(label: String, isSet: Bool, time: TimeInterval?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSet ? .white : .primary)
                if let time = time {
                    Text(formatDuration(time))
                        .font(.caption2)
                        .foregroundStyle(isSet ? .white.opacity(0.8) : .secondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                isSet ?
                    AnyShapeStyle(Color.accentColor.gradient) :
                    AnyShapeStyle(.thinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSet ? Color.accentColor.opacity(0.3) : .separator.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
