import Foundation
import AVFoundation
import Combine

@MainActor
class AudioManager: ObservableObject {
    
    enum AudioClient {
        case recorder, player, tuner, metronome
    }
    
    @Published private(set) var activeClient: AudioClient?
    
    // --- THIS IS THE FIX: Separate audio players for the upbeat and downbeat sounds ---
    private var metronomeUpbeatPlayer: AVAudioPlayer?
    private var metronomeDownbeatPlayer: AVAudioPlayer?

    init() {
        setupMetronomePlayers()
    }
    
    func requestSession(for client: AudioClient, category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions = []) -> Bool {
        let session = AVAudioSession.sharedInstance()
        
        print("AudioManager: Requesting session for \(client)")
        
        if activeClient != nil && activeClient != client {
            print("AudioManager: Deactivating previous client (\(String(describing: activeClient))) for new client (\(client)).")
        }
        
        do {
            // Special handling for tuner - it needs a clean audio session
            if client == .tuner {
                print("AudioManager: Setting up clean session for tuner...")
                
                // Deactivate any existing session
                try session.setActive(false, options: .notifyOthersOnDeactivation)
                
                // Small delay to ensure clean deactivation
                Thread.sleep(forTimeInterval: 0.2)
                
                // Set category and options specifically for recording
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
                
                // Activate the session
                try session.setActive(true)
                
                // Verify input is available
                guard session.isInputAvailable else {
                    print("AudioManager: Input not available after session setup")
                    return false
                }
                
                print("AudioManager: Tuner session configured successfully")
                print("AudioManager: Input available: \(session.isInputAvailable)")
                print("AudioManager: Current route: \(session.currentRoute)")
                
            } else {
                // Standard handling for other clients
                try session.setActive(false)
                try session.setCategory(category, mode: .default, options: options)
                try session.setActive(true)
            }
            
            self.activeClient = client
            print("AudioManager: Session activated for \(client).")
            return true
            
        } catch {
            print("AudioManager: Failed to request session for \(client). Error: \(error.localizedDescription)")
            self.activeClient = nil
            return false
        }
    }
    
    func releaseSession(for client: AudioClient) {
        guard activeClient == client else {
            print("AudioManager: Ignoring release request from inactive client \(client). Active is \(String(describing: activeClient)).")
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.activeClient = nil
            print("AudioManager: Session released by \(client).")
        } catch {
            print("AudioManager: Failed to release session for \(client). Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Metronome Specific Logic
    
    // --- THIS IS THE FIX: Updated setup function to load both sound files ---
    private func setupMetronomePlayers() {
        guard let upbeatURL = Bundle.main.url(forResource: "tick", withExtension: "wav"),
              let downbeatURL = Bundle.main.url(forResource: "tick_down", withExtension: "wav") else {
            print("Could not find the sound file 'tick.wav' or 'tick_down.wav' in the bundle.")
            return
        }
        do {
            metronomeUpbeatPlayer = try AVAudioPlayer(contentsOf: upbeatURL)
            metronomeUpbeatPlayer?.prepareToPlay()
            
            metronomeDownbeatPlayer = try AVAudioPlayer(contentsOf: downbeatURL)
            metronomeDownbeatPlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize metronome players: \(error.localizedDescription)")
        }
    }
    
    // --- THIS IS THE FIX: New function to play the downbeat sound ---
    func playMetronomeDownbeat() {
        if activeClient == .metronome || activeClient == .recorder {
            metronomeDownbeatPlayer?.currentTime = 0
            metronomeDownbeatPlayer?.play()
        }
    }
    
    // --- THIS IS THE FIX: Renamed function for clarity ---
    func playMetronomeUpbeat() {
        if activeClient == .metronome || activeClient == .recorder {
            metronomeUpbeatPlayer?.currentTime = 0
            metronomeUpbeatPlayer?.play()
        }
    }
    
    func playSineWave(frequency: Double, duration: TimeInterval) {
        let hasSession = requestSession(for: .player, category: .playback)
        guard hasSession else { return }

        // Use a local engine instance for this one-off sound
        let audioEngine = AVAudioEngine()
        let mainMixer = audioEngine.mainMixerNode
        let output = audioEngine.outputNode
        let format = output.inputFormat(forBus: 0)

        // Create an instance of our generator
        let sineGenerator = SineWaveGenerator(sampleRate: format.sampleRate, frequency: frequency)

        // The render closure is now much simpler for the compiler to understand
        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            // It just calls the render method on our helper class
            sineGenerator.render(bufferList: abl, frameCount: frameCount)
            return noErr
        }

        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: mainMixer, format: format)
        audioEngine.connect(mainMixer, to: output, format: nil)

        do {
            try audioEngine.start()
            // Schedule the engine to stop after the desired duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                audioEngine.stop()
                self.releaseSession(for: .player)
            }
        } catch {
            print("Error playing sine wave: \(error)")
            releaseSession(for: .player)
        }
    }

}

// Helper class to manage sine wave generation state
private class SineWaveGenerator {
    var phase: Float = 0
    let sampleRate: Double
    let frequency: Double

    init(sampleRate: Double, frequency: Double) {
        self.sampleRate = sampleRate
        self.frequency = frequency
    }

    func render(bufferList: UnsafeMutableAudioBufferListPointer, frameCount: UInt32) {
        let sampleRate = Float(self.sampleRate)
        let frequency = Float(self.frequency)

        for frame in 0..<Int(frameCount) {
            // Calculate the sine wave value
            let value = sin(2 * .pi * self.phase) * 0.5
            
            // Increment the phase for the next sample
            self.phase += frequency / sampleRate
            if self.phase > 1.0 {
                self.phase -= 1.0
            }
            
            // Fill the audio buffer
            for buffer in bufferList {
                let typedBuffer = buffer.mData!.assumingMemoryBound(to: Float.self)
                typedBuffer[frame] = value
            }
        }
    }
}

