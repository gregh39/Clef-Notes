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
    private let engine = AudioEngine()
    private var mic: AudioEngine.InputNode
    // --- FIX: Make tracker an implicitly unwrapped optional ---
    private var tracker: PitchTap!
    private var mixer: Mixer
    
    private let audioManager: AudioManager

    // Note names for manual calculation
    private static let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private var a4Frequency: Double = SettingsManager.shared.a4Frequency
    private var transposition: Int = SettingsManager.shared.tunerTransposition
    
    private var settingsCancellable: AnyCancellable?


    // MARK: - Initialization

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        print("[PitchTunerViewModel] Initialized with AudioManager")
        mic = engine.input!
        print("[PitchTunerViewModel] Mic input initialized")
        mixer = Mixer(mic)
        print("[PitchTunerViewModel] Mixer initialized")
        engine.output = mixer
        print("[PitchTunerViewModel] Engine output set to mixer")
        
        // --- FIX: Initialize tracker after other properties are set ---
        // The closure can now safely capture `self` because all other properties are initialized.
        tracker = PitchTap(mic) { [weak self] pitch, amp in
            DispatchQueue.main.async {
                self?.update(pitch: pitch[0], amp: amp[0])
            }
        }
        print("[PitchTunerViewModel] PitchTap (tracker) initialized")
        
        settingsCancellable = SettingsManager.shared.objectWillChange.sink { [weak self] _ in
            self?.a4Frequency = SettingsManager.shared.a4Frequency
            self?.transposition = SettingsManager.shared.tunerTransposition
        }
        print("[PitchTunerViewModel] SettingsManager subscription set up")
    }

    // MARK: - Public Methods

    func start() {
        print("[PitchTunerViewModel] start() called")

        let requested = audioManager.requestSession(for: .tuner, category: .record, options: [])
        print("[PitchTunerViewModel] Requested audio session for tuner: \(requested)")
        guard requested else {
            print("[PitchTunerViewModel] Failed to request audio session for tuner")
            return
        }
        
        // Request microphone permission directly.
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            if !granted {
                print("[PitchTunerViewModel] Microphone permission denied.")
                TelemetryDeck.signal("mic_permission_denied")
                return
            }
            
            print("[PitchTunerViewModel] Microphone permission granted. Starting tracker and engine...")
            
            DispatchQueue.main.async {
                do {
                    // Start the tracker and then the engine.
                    // AudioKit will handle activating the audio session.
                    self.tracker.start()
                    print("[PitchTunerViewModel] Tracker started.")
                    try self.engine.start()
                    print("[PitchTunerViewModel] Engine started.")
                    self.isListening = true
                    TelemetryDeck.signal("tuner_started")
                } catch {
                    print("[PitchTunerViewModel] Error starting AudioKit engine: \(error)")
                }
            }
        }
    }

    func stop() {
        print("[PitchTunerViewModel] stop() called")
        guard isListening else {
            print("[PitchTunerViewModel] Was not listening. Nothing to stop.")
            return
        }
        
        engine.stop()
        print("[PitchTunerViewModel] Audio engine stopped.")
        isListening = false
        TelemetryDeck.signal("tuner_stopped")
        print("[PitchTunerViewModel] isListening set to false.")
        audioManager.releaseSession(for: .tuner)
        print("[PitchTunerViewModel] Audio session released for tuner.")
        
        
        detectedNoteName = "--"
        detectedFrequency = 440.0
        distance = 0.0

    }

    // MARK: - Private Methods

    private func update(pitch: AUValue, amp: AUValue) {
        print("[PitchTunerViewModel] update(pitch: \(pitch), amp: \(amp)) called")
        // Only update if the amplitude is high enough to be intentional
        guard amp > 0.01 else {
            print("[PitchTunerViewModel] Amplitude too low (\(amp)). Update skipped.")
            self.distance = 0.0
            return
        }

        let detectedFrequency = Double(pitch)
        self.detectedFrequency = detectedFrequency
        print("[PitchTunerViewModel] Detected frequency updated: \(detectedFrequency)")

        // Manual Pitch Calculation
        let halfStepsFromA4 = 12 * log2(detectedFrequency / a4Frequency)
        let closestHalfStep = Int(round(halfStepsFromA4))
        let perfectFrequency = a4Frequency * pow(2.0, Double(closestHalfStep) / 12.0)
        let distanceInCents = 1200 * log2(detectedFrequency / perfectFrequency)

        print("[PitchTunerViewModel] Calculated closest half step: \(closestHalfStep)")
        print("[PitchTunerViewModel] Perfect frequency: \(perfectFrequency)")
        print("[PitchTunerViewModel] Distance in cents: \(distanceInCents)")

        let noteIndex = (closestHalfStep + 9 + 120 + transposition) % 12
        let octave = 4 + (closestHalfStep + 9 + transposition) / 12
        
        self.detectedNoteName = "\(PitchTunerViewModel.noteNamesWithSharps[noteIndex])\(octave)"
        self.distance = min(max(distanceInCents / 50.0, -1.0), 1.0)
        print("[PitchTunerViewModel] Detected note: \(self.detectedNoteName), Distance: \(self.distance)")
    }
}
