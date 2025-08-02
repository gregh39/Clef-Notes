import Foundation
import AudioKit
import SoundpipeAudioKit
import AVFoundation
import SwiftUI
import Combine

@MainActor
class PitchTunerViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published var detectedNoteName = "--"
    @Published var detectedFrequency: Double = 440.0
    @Published var distance: Double = 0.0
    @Published var isListening = false

    // --- FIX: Let AudioKit manage the session ---
    private let engine = AudioEngine()
    private var mic: AudioEngine.InputNode
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
        mic = engine.input!
        mixer = Mixer(mic)

        // --- FIX: Set mixer volume to 0 to prevent feedback ---
        mixer.volume = 0
        engine.output = mixer
        
        // Initialize tracker after other properties are set
        tracker = PitchTap(mic) { [weak self] pitch, amp in
            DispatchQueue.main.async {
                self?.update(pitch: pitch[0], amp: amp[0])
            }
        }
        
        settingsCancellable = SettingsManager.shared.objectWillChange.sink { [weak self] _ in
            self?.a4Frequency = SettingsManager.shared.a4Frequency
            self?.transposition = SettingsManager.shared.tunerTransposition
        }
    }

    // MARK: - Public Methods

    /*func start() {
        // Request microphone permission first.
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard let self = self, granted else {
                print("Microphone permission denied.")
                return
            }
            
            DispatchQueue.main.async {
                do {
                    // Let AudioKit manage the session by setting its category.
                    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                    
                    // Start the tracker and then the engine.
                    self.tracker.start()
                    try self.engine.start()
                    self.isListening = true
                    
                    print("AudioKit engine started successfully")
                } catch {
                    print("Error starting AudioKit engine: \(error)")
                    // Attempt a fallback if the primary start fails
                    self.startWithFallback()
                }
            }
        }
    }*/
    
    private func startWithFallback() {
        do {
            // --- FIX: Alternative initialization approach ---
            // Stop and reset everything first
            engine.stop()
            
            // Try a different session configuration
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false)
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true)
            
            // Restart tracker and engine
            tracker.start()
            try engine.start()
            self.isListening = true
            
            print("AudioKit engine started with fallback configuration")
        } catch {
            print("Fallback also failed: \(error)")
            self.isListening = false
        }
    }

    @MainActor
    func start() {
        // Immediately return if the tuner is already in the "listening" state.
        guard !isListening else { return }

        // Request microphone permission from the user.
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard let self = self, granted else {
                print("Microphone permission was denied.")
                return
            }

            // Perform the start-stop-start sequence.
            Task {
                do {
                    // --- The "Secret" Start-Stop Cycle ---
                    // This first cycle "primes the pump" for the audio session. It happens so
                    // fast the user won't notice. We ignore any errors it throws.
                    try? self.engine.start()
                    self.engine.stop()

                    // --- The "Real" Start ---
                    // This is the second start, which should now work reliably.
                    // We re-apply the session settings to be safe.
                    try Settings.session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
                    self.tracker.start()
                    try self.engine.start()

                    // --- Update the UI ---
                    // Now that it's successfully running, update the state on the main thread.
                    await MainActor.run {
                        self.isListening = true
                        print("✅ Pitch Tuner: Engine started successfully using the workaround.")
                    }

                } catch {
                    // If the workaround fails, print the error and ensure we're stopped.
                    await MainActor.run {
                        print("🛑 Pitch Tuner: The start-stop-start workaround failed. Error: \(error.localizedDescription)")
                        self.stop()
                    }
                }
            }
        }
    }
    func stop() {
        guard isListening else { return }

        // Stop the engine and pitch tracker.
        engine.stop()
        tracker.stop()

        // It's good practice to try to deactivate the session when you're done.
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("🛑 Pitch Tuner: Could not deactivate audio session. Error: \(error.localizedDescription)")
        }

        // Reset the UI state.
        isListening = false
        detectedNoteName = "--"
        detectedFrequency = 440.0
        distance = 0.0
    }    // MARK: - Private Methods

    private func update(pitch: AUValue, amp: AUValue) {
        // Only update if the amplitude is high enough to be intentional
        guard amp > 0.1 else {
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
    
    deinit {
        settingsCancellable?.cancel()
        
        // Clean up without calling @MainActor methods
        engine.stop()
        
        // Reset audio session safely
        Task { @MainActor in
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Error deactivating audio session in deinit: \(error)")
            }
        }
    }
}
