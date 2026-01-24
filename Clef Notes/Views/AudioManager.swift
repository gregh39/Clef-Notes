import Foundation
import AVFoundation
import Combine

@MainActor
class AudioManager: ObservableObject {

    // Singleton instance
    static let shared = AudioManager()

    enum AudioClient {
        case recorder, player, tuner, metronome, timer
    }

    @Published private(set) var activeClient: AudioClient?

    // --- THIS IS THE FIX: Separate audio players for the upbeat and downbeat sounds ---
    private var metronomeUpbeatPlayer: AVAudioPlayer?
    private var metronomeDownbeatPlayer: AVAudioPlayer?

    // Silent audio player for background timer
    private var timerSilentPlayer: AVAudioPlayer?
    private var timerShouldBeRunning = false
    private var previousClient: AudioClient?

    init() {
        setupMetronomePlayers()
        setupTimerSilentPlayer()
        setupAudioInterruptionHandling()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupAudioInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Another app (like YouTube) started playing audio
            print("AudioManager: Audio interrupted - client: \(String(describing: activeClient))")

        case .ended:
            // The other app stopped, we can resume our audio if needed
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            if options.contains(.shouldResume) {
                print("AudioManager: Interruption ended - should resume, timerShouldBeRunning: \(timerShouldBeRunning)")

                // Resume timer audio if it should be running
                if timerShouldBeRunning {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        let hasSession = requestSession(for: .timer, category: .playback, options: .mixWithOthers)
                        if hasSession {
                            timerSilentPlayer?.play()
                            print("AudioManager: Timer audio resumed after interruption")
                        }
                    } catch {
                        print("AudioManager: Failed to resume audio session: \(error)")
                    }
                }
            }

        @unknown default:
            break
        }
    }
    
    func requestSession(for client: AudioClient, category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions = []) -> Bool {
        let session = AVAudioSession.sharedInstance()

        print("AudioManager: Requesting session for \(client)")

        if activeClient != nil && activeClient != client {
            print("AudioManager: Deactivating previous client (\(String(describing: activeClient))) for new client (\(client)).")
            previousClient = activeClient
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

            // If timer should be running and was interrupted by another client, restart it
            if timerShouldBeRunning && previousClient == .timer {
                print("AudioManager: Restarting timer audio after \(client) released session")
                startTimerAudio()
                previousClient = nil
            }
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

    // MARK: - Timer Specific Logic

    private func setupTimerSilentPlayer() {
        // Create a silent audio file for background timer
        let silenceURL = createSilentAudioFile()

        do {
            timerSilentPlayer = try AVAudioPlayer(contentsOf: silenceURL)
            timerSilentPlayer?.numberOfLoops = -1 // Loop indefinitely
            timerSilentPlayer?.volume = 0.0 // Silent
            timerSilentPlayer?.prepareToPlay()
        } catch {
            print("Failed to create timer silent audio player: \(error)")
        }
    }

    private func createSilentAudioFile() -> URL {
        // Create a silent audio file (1 second of silence)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let frameCount = AVAudioFrameCount(44100) // 1 second
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Write to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("timer_silence.m4a")

        // If file already exists, return it
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        // Create a simple silent audio file
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 64000
        ]

        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            try audioFile.write(from: buffer)
        } catch {
            print("Failed to create silent audio file: \(error)")
        }

        return fileURL
    }

    func startTimerAudio() {
        timerShouldBeRunning = true
        let hasSession = requestSession(for: .timer, category: .playback, options: .mixWithOthers)
        guard hasSession else {
            print("AudioManager: Failed to acquire session for timer")
            return
        }
        timerSilentPlayer?.play()
        print("AudioManager: Timer silent audio started")
    }

    func stopTimerAudio() {
        timerShouldBeRunning = false
        timerSilentPlayer?.stop()
        releaseSession(for: .timer)
        print("AudioManager: Timer silent audio stopped")
    }

    func pauseTimerAudio() {
        timerShouldBeRunning = false
        timerSilentPlayer?.pause()
        print("AudioManager: Timer silent audio paused")
    }

    func resumeTimerAudio() {
        timerShouldBeRunning = true
        timerSilentPlayer?.play()
        print("AudioManager: Timer silent audio resumed")
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

