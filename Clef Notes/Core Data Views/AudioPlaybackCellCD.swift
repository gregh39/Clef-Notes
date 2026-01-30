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
    @State private var isExpanded = false

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
        VStack(alignment: .leading, spacing: 14) {
            // Header row - tappable to expand
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
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

                    // Expand/collapse indicator
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Playback controls (when expanded)
            if isExpanded {
                // Action buttons row
                HStack(spacing: 10) {
                    if let audioData = data {
                        ShareLink(
                            item: AudioFile(data: audioData, filename: "\(title).m4a"),
                            preview: SharePreview(title, image: Image(systemName: "waveform"))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
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
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(data == nil)
                    .buttonStyle(.plain)
                }
                VStack(spacing: 14) {
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

                    // Control buttons
                    HStack(spacing: 0) {
                        // Skip back
                        controlButton(icon: "gobackward.5") {
                            audioPlayerManager.skipBackward()
                        }
                        .disabled(!isPlaying && audioPlayerManager.currentlyPlayingID != id)

                        Divider()
                            .frame(height: 20)

                        // Stop
                        controlButton(icon: "stop.fill") {
                            audioPlayerManager.stop()
                        }
                        .disabled(audioPlayerManager.currentlyPlayingID != id)

                        Divider()
                            .frame(height: 20)

                        // Skip forward
                        controlButton(icon: "goforward.5") {
                            audioPlayerManager.skipForward()
                        }
                        .disabled(!isPlaying && audioPlayerManager.currentlyPlayingID != id)

                        Divider()
                            .frame(height: 20)

                        // Speed control
                        controlButton(icon: nil, label: "\(Int(audioPlayerManager.playbackRate * 100))%") {
                            withAnimation(.spring(response: 0.3)) {
                                showSpeedControl.toggle()
                            }
                        }
                    }
                    .frame(height: 42)

                    // Loop Points Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loop Points")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

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
                                            .font(.caption)
                                        Text("Loop")
                                            .font(.caption.weight(.medium))
                                    }
                                    .foregroundStyle(audioPlayerManager.isLooping ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(
                                        audioPlayerManager.isLooping ?
                                            AnyShapeStyle(Color.accentColor) :
                                            AnyShapeStyle(.quaternary.opacity(0.4))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    audioPlayerManager.clearLoop()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.plain)
                            }
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
                                    .font(.subheadline.weight(.semibold))
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
                        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                        .font(.title3)
                } else if let label = label {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
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
                        .foregroundStyle(isSet ? .white.opacity(0.9) : .secondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                isSet ?
                    AnyShapeStyle(Color.accentColor) :
                    AnyShapeStyle(.quaternary.opacity(0.4))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
