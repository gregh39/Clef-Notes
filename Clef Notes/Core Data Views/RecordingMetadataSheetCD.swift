import SwiftUI
import CoreData
import AVFoundation

struct RecordingMetadataSheetCD: View {
    let fileURL: URL
    let songs: [SongCD]

    @Binding var newRecordingTitle: String
    @Binding var selectedSongs: Set<SongCD>

    var onSave: (String, Set<SongCD>) -> Void
    var onRetake: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingPreview = true
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackTimer: Timer?
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var waveformSamples: [CGFloat] = []

    var body: some View {
        NavigationStack {
            if showingPreview {
                previewView
            } else {
                metadataView
            }
        }
        .onAppear {
            setupAudioPlayer()
            generateDefaultTitle()
            generateWaveform()
        }
        .onDisappear {
            playbackTimer?.invalidate()
            playbackTimer = nil
            stopPlayback()
            audioPlayer = nil
        }
    }

    private var previewView: some View {
        VStack(spacing: 24) {
            // Waveform visualization
            if !waveformSamples.isEmpty {
                RecordingWaveformView(
                    samples: waveformSamples,
                    currentTime: currentTime,
                    duration: duration
                )
                .frame(height: 120)
                .padding(.horizontal)
            }

            // Time display
            HStack {
                Text(formatTime(currentTime))
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Text(formatTime(duration))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            // Playback controls
            HStack(spacing: 40) {
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                }

                Button(action: restartPlayback) {
                    Image(systemName: "gobackward")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    stopPlayback()
                    showingPreview = false
                }) {
                    Text("Keep & Add Details")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        stopPlayback()
                        onRetake()
                        dismiss()
                    }) {
                        Text("Retake")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                    }

                    Button(role: .destructive, action: {
                        stopPlayback()
                        dismiss()
                    }) {
                        Text("Discard")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Preview Recording")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metadataView: some View {
        VStack {
            Form {
                Section("Recording Info") {
                    TextField("Recording Title (Optional)", text: $newRecordingTitle)
                    Text(duration > 0 ? "Duration: \(formatTime(duration))" : "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("Tag Songs (Optional)") {
                    if songs.isEmpty {
                        Text("No songs available.").foregroundColor(.secondary)
                    } else {
                        ForEach(songs) { song in
                            MultipleSelectionRowCD(
                                title: song.title ?? "Unknown",
                                isSelected: selectedSongs.contains(song)
                            ) {
                                if selectedSongs.contains(song) {
                                    selectedSongs.remove(song)
                                } else {
                                    selectedSongs.insert(song)
                                }
                            }
                        }
                    }
                }
            }

            SaveButtonView(title: "Save Recording", action: {
                let finalTitle = newRecordingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                onSave(finalTitle, selectedSongs)
                dismiss()
            }, isDisabled: false)
        }
        .navigationTitle("Add Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    showingPreview = true
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func setupAudioPlayer() {
        do {
            let data = try Data(contentsOf: fileURL)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
        } catch {
            print("Error setting up audio player: \(error)")
        }
    }

    private func generateDefaultTitle() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        newRecordingTitle = "Recording \(formatter.string(from: Date()))"
    }

    private func generateWaveform() {
        guard let player = audioPlayer else { return }

        let sampleCount = 100
        let samples = extractWaveformSamples(from: fileURL, sampleCount: sampleCount)
        waveformSamples = samples
    }

    private func extractWaveformSamples(from url: URL, sampleCount: Int) -> [CGFloat] {
        // Simplified waveform generation
        // In a production app, you'd want to use AVAssetReader for more accurate waveforms
        guard let player = audioPlayer else { return Array(repeating: 0.3, count: sampleCount) }

        // For now, return a placeholder waveform
        // Real implementation would analyze the audio file
        return (0..<sampleCount).map { _ in
            CGFloat.random(in: 0.2...0.9)
        }
    }

    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }

    private func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        playbackTimer?.invalidate()
    }

    private func restartPlayback() {
        audioPlayer?.currentTime = 0
        currentTime = 0
        if isPlaying {
            audioPlayer?.play()
        }
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            currentTime = audioPlayer?.currentTime ?? 0
            if currentTime >= duration {
                stopPlayback()
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct MultipleSelectionRowCD: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recording Waveform View
private struct RecordingWaveformView: View {
    let samples: [CGFloat]
    let currentTime: TimeInterval
    let duration: TimeInterval

    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background waveform
                HStack(alignment: .center, spacing: 2) {
                    ForEach(samples.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(width: max(2, geometry.size.width / CGFloat(samples.count) - 2))
                            .frame(height: samples[index] * geometry.size.height)
                    }
                }

                // Foreground (played) waveform
                HStack(alignment: .center, spacing: 2) {
                    ForEach(samples.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: max(2, geometry.size.width / CGFloat(samples.count) - 2))
                            .frame(height: samples[index] * geometry.size.height)
                    }
                }
                .mask(
                    Rectangle()
                        .frame(width: geometry.size.width * progress)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )

                // Playhead indicator
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .offset(x: geometry.size.width * progress)
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
