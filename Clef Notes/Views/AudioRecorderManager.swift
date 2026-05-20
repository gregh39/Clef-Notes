// Clef Notes/Views/AudioRecorderManager.swift

import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
class AudioRecorderManager: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var waveformSamples: [CGFloat] = []
    @Published var finishedRecordingURL: URL?
    @Published var elapsedTime: TimeInterval = 0
    @Published var elapsedTimeString: String = "00:00"

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var elapsedTimer: Timer?
    private weak var audioManager: AudioManager? // Weak reference
    private let numberOfSamples = 50
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }
    
    deinit {
        recordingTimer?.invalidate()
        recordingTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
    }

    private func cleanup() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
    }

    func startRecording() {
        cleanup() // Ensure clean state

        waveformSamples = Array(repeating: 0.0, count: numberOfSamples)
        elapsedTime = 0
        pausedDuration = 0
        elapsedTimeString = "00:00"
        isPaused = false

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

            recordingStartTime = Date()
            isRecording = true
            startMeteringTimer()
            startElapsedTimer()

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

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
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

    private func updateElapsedTime() {
        guard let startTime = recordingStartTime, !isPaused else { return }
        elapsedTime = Date().timeIntervalSince(startTime) - pausedDuration
        elapsedTimeString = formatElapsedTime(elapsedTime)
    }

    private func formatElapsedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        audioRecorder?.pause()
        isPaused = true
        pauseStartTime = Date()
        recordingTimer?.invalidate()
        recordingTimer = nil
        // Keep elapsed timer running to update display
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        audioRecorder?.record()
        isPaused = false
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        startMeteringTimer()
    }

    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil

        audioRecorder?.stop()
        isRecording = false
        isPaused = false
        finishedRecordingURL = audioRecorder?.url

        audioManager?.releaseSession(for: .recorder)
    }

    func reset() {
        cleanup()
        waveformSamples = []
        finishedRecordingURL = nil
        elapsedTime = 0
        elapsedTimeString = "00:00"
        isPaused = false
        pausedDuration = 0
        pauseStartTime = nil
        recordingStartTime = nil
    }
}
