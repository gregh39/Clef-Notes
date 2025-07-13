import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
class AudioRecorderManager: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: CGFloat = 0.0
    @Published var finishedRecordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    
    // The manager now holds a reference to the central AudioManager.
    private var audioManager: AudioManager

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }

    /// Starts a new audio recording.
    func startRecording() {
        // Request the session from the central manager.
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
            // The session is already active and configured by the AudioManager.
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            
            // Start a timer to get the audio levels for the waveform.
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.audioRecorder?.updateMeters()
                let power = self?.audioRecorder?.averagePower(forChannel: 0) ?? -160.0
                self?.audioLevel = CGFloat((160.0 + power) / 160.0)
            }
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            // If something goes wrong, release the session.
            audioManager.releaseSession(for: .recorder)
        }
    }

    /// Stops the current recording and publishes the URL of the finished file.
    func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        
        self.finishedRecordingURL = audioRecorder?.url
        
        isRecording = false
        audioLevel = 0.0
        
        // Release the session via the central manager.
        audioManager.releaseSession(for: .recorder)
    }
}
