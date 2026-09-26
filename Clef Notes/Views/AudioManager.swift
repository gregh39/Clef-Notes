import Foundation
import AVFoundation
import Combine

@MainActor
class AudioManager: ObservableObject {

    // Singleton instance
    static let shared = AudioManager()

    enum AudioClient {
        case recorder, player, tuner, metronome
    }

    @Published private(set) var activeClient: AudioClient?

    /// Configures and activates the shared audio session for `client`.
    ///
    /// The category is changed on the already-active session rather than deactivating first:
    /// deactivating fails with "session busy" while another client's I/O is still running
    /// (e.g. starting a recording while the metronome plays). Clients that own an
    /// `AVAudioEngine` observe configuration changes and restart themselves.
    func requestSession(for client: AudioClient, category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions = []) -> Bool {
        let session = AVAudioSession.sharedInstance()

        do {
            if client == .tuner {
                // The tuner needs a measurement-mode input with no system processing.
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
                try session.setActive(true)

                guard session.isInputAvailable else {
                    print("AudioManager: Input not available for tuner")
                    return false
                }
            } else {
                try session.setCategory(category, mode: .default, options: options)
                try session.setActive(true)
            }

            self.activeClient = client
            return true

        } catch {
            print("AudioManager: Failed to request session for \(client). Error: \(error.localizedDescription)")
            self.activeClient = nil
            return false
        }
    }

    func releaseSession(for client: AudioClient) {
        guard activeClient == client else { return }

        // Clear ownership even if deactivation fails (it can while other I/O is still running),
        // so the next client isn't blocked by a stale owner.
        self.activeClient = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioManager: Failed to deactivate session for \(client). Error: \(error.localizedDescription)")
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

