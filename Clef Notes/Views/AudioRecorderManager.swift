// Clef Notes/Views/AudioRecorderManager.swift

import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
class AudioRecorderManager: ObservableObject {
    @Published var isRecording = false
    @Published var waveformSamples: [CGFloat] = []
    @Published var finishedRecordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private let numberOfSamples = 50 // The number of samples to show in the waveform
    
    private var audioManager: AudioManager

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }

    func startRecording() {
        waveformSamples = Array(repeating: 0.0, count: numberOfSamples) // Pre-fill with silence
        let hasSession = audioManager.requestSession(for: .recorder, category: .playAndRecord, options: .defaultToSpeaker)
        guard hasSession else {
            print("AudioRecorderManager: Failed to acquire audio session.")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.audioRecorder?.updateMeters()
                
                // --- THIS IS THE FIX ---
                // Set a more restrictive decibel floor to ignore background noise.
                let minDb: Float = -40.0
                let power = self.audioRecorder?.averagePower(forChannel: 0) ?? minDb
                
                // Ensure the power is at least the minimum, then normalize it to a 0-1 range.
                let normalizedPower = max(0, (power - minDb) / (0 - minDb))
                
                // Apply a power curve (cubing the value) to make the visualization
                // far less sensitive to quiet sounds and more responsive to loud ones.
                let newSample = CGFloat(pow(normalizedPower, 3))
                // --- END OF FIX ---
                
                self.waveformSamples.append(newSample)
                if self.waveformSamples.count > self.numberOfSamples {
                    self.waveformSamples.removeFirst()
                }
            }
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            audioManager.releaseSession(for: .recorder)
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        isRecording = false
        self.finishedRecordingURL = audioRecorder?.url
        audioManager.releaseSession(for: .recorder)
    }
    
    func reset() {
        waveformSamples = []
        finishedRecordingURL = nil
    }
}
