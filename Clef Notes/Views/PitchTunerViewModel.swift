import Foundation
import AudioKit
import SoundpipeAudioKit
import AVFoundation
import SwiftUI
import Combine
import TelemetryDeck

@MainActor
class PitchTunerViewModel: ObservableObject {
    // MARK: - Properties

    @Published var detectedNoteName = "--"
    @Published var detectedFrequency: Double = 440.0
    @Published var distance: Double = 0.0
    @Published var isListening = false

    // AudioKit Engine - now self-contained
    private var engine: AudioEngine!
    private var mic: AudioEngine.InputNode!
    private var tracker: PitchTap!
    private var mixer: Mixer!

    private let audioManager: AudioManager

    // Note names for manual calculation
    private static let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private var a4Frequency: Double = SettingsManager.shared.a4Frequency
    private var transposition: Int = SettingsManager.shared.tunerTransposition

    private var settingsCancellable: AnyCancellable?


    // MARK: - Initialization

    init(audioManager: AudioManager) {
        self.audioManager = audioManager

        settingsCancellable = SettingsManager.shared.objectWillChange.sink { [weak self] _ in
            self?.a4Frequency = SettingsManager.shared.a4Frequency
            self?.transposition = SettingsManager.shared.tunerTransposition
        }
    }

    private func setupAudioEngine() {
        // Stop and reset existing engine if it exists
        if engine != nil {
            engine.stop()
        }

        // Create fresh engine after audio session is configured
        engine = AudioEngine()
        mic = engine.input
        mixer = Mixer(mic)
        engine.output = mixer

        // Initialize tracker after other properties are set
        tracker = PitchTap(mic) { [weak self] pitch, amp in
            DispatchQueue.main.async {
                self?.update(pitch: pitch[0], amp: amp[0])
            }
        }
    }

    // MARK: - Public Methods

    func start() {
        let requested = audioManager.requestSession(for: .tuner, category: .record, options: [])
        guard requested else { return }

        // Request microphone permission directly.
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            if !granted {
                TelemetryDeck.signal("mic_permission_denied")
                return
            }

            DispatchQueue.main.async {
                do {
                    // Setup engine AFTER audio session is configured
                    self.setupAudioEngine()

                    // Start the tracker and then the engine.
                    // AudioKit will handle activating the audio session.
                    self.tracker.start()
                    try self.engine.start()
                    self.isListening = true
                    TelemetryDeck.signal("tuner_started")
                } catch {
                    print("PitchTunerViewModel: Error starting AudioKit engine: \(error)")
                }
            }
        }
    }

    func stop() {
        guard isListening else { return }

        engine?.stop()
        isListening = false
        TelemetryDeck.signal("tuner_stopped")
        audioManager.releaseSession(for: .tuner)

        detectedNoteName = "--"
        detectedFrequency = 440.0
        distance = 0.0
    }

    // MARK: - Private Methods

    private func update(pitch: AUValue, amp: AUValue) {
        // Only update if the amplitude is high enough to be intentional
        guard amp > 0.01 else {
            self.distance = 0.0
            return
        }

        let detectedFrequency = Double(pitch)
        self.detectedFrequency = detectedFrequency

        // Manual Pitch Calculation
        let halfStepsFromA4 = 12 * log2(detectedFrequency / a4Frequency)
        let closestHalfStep = Int(round(halfStepsFromA4))
        let perfectFrequency = a4Frequency * pow(2.0, Double(closestHalfStep) / 12.0)
        let distanceInCents = 1200 * log2(detectedFrequency / perfectFrequency)

        let noteIndex = (closestHalfStep + 9 + 120 + transposition) % 12
        let octave = 4 + (closestHalfStep + 9 + transposition) / 12

        self.detectedNoteName = "\(PitchTunerViewModel.noteNamesWithSharps[noteIndex])\(octave)"
        self.distance = min(max(distanceInCents / 50.0, -1.0), 1.0)
    }
}
