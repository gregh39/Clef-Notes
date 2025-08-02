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
    private weak var audioManager: AudioManager? // Weak reference
    private let numberOfSamples = 50

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }
    
    deinit {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
    }
    
    private func cleanup() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
    }

    func startRecording() {
        cleanup() // Ensure clean state
        
        waveformSamples = Array(repeating: 0.0, count: numberOfSamples)
        
        guard let audioManager = audioManager else {
            AppLogger.shared.logError(ClefNotesError.audioSessionError("AudioManager is nil"))
            return
        }
        
        let hasSession = audioManager.requestSession(for: .recorder, category: .playAndRecord, options: .defaultToSpeaker)
        guard hasSession else {
            AppLogger.shared.logError(ClefNotesError.audioSessionError("Failed to acquire audio session"))
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
            startMeteringTimer()
            
        } catch {
            AppLogger.shared.logError(ClefNotesError.audioSessionError("Failed to start recording: \(error.localizedDescription)"))
            audioManager.releaseSession(for: .recorder)
        }
    }
    
    private func startMeteringTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateMetering()
        }
    }
    
    private func updateMetering() {
        audioRecorder?.updateMeters()
        
        let minDb: Float = -40.0
        let power = audioRecorder?.averagePower(forChannel: 0) ?? minDb
        let normalizedPower = max(0, (power - minDb) / (0 - minDb))
        let newSample = CGFloat(pow(normalizedPower, 3))
        
        waveformSamples.append(newSample)
        if waveformSamples.count > numberOfSamples {
            waveformSamples.removeFirst()
        }
    }

    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioRecorder?.stop()
        isRecording = false
        finishedRecordingURL = audioRecorder?.url
        
        audioManager?.releaseSession(for: .recorder)
    }
    
    func reset() {
        cleanup()
        waveformSamples = []
        finishedRecordingURL = nil
    }
}
