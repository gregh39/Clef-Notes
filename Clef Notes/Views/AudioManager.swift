import Foundation
import AVFoundation
import Combine

@MainActor
class AudioManager: ObservableObject {
    
    enum AudioClient {
        case recorder, player, tuner, metronome
    }
    
    // The current client that has control of the audio session.
    @Published private(set) var activeClient: AudioClient?
    
    private var metronomePlayer: AVAudioPlayer?

    init() {
        setupMetronomePlayer()
    }
    
    /// A component requests control of the audio session.
    /// This function will deactivate any existing session before configuring a new one.
    func requestSession(for client: AudioClient, category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions = []) -> Bool {
        let session = AVAudioSession.sharedInstance()
        
        if activeClient != nil && activeClient != client {
            print("AudioManager: Deactivating previous client (\(String(describing: activeClient))) for new client (\(client)).")
        }
        
        do {
            // Deactivate any currently active session to prevent conflicts.
            try session.setActive(false)
            
            // Set the category and options requested by the new client.
            try session.setCategory(category, mode: .default, options: options)
            
            // Activate the new session.
            try session.setActive(true)
            
            // Mark the new client as active.
            self.activeClient = client
            print("AudioManager: Session activated for \(client).")
            return true
            
        } catch {
            print("AudioManager: Failed to request session for \(client). Error: \(error.localizedDescription)")
            self.activeClient = nil
            return false
        }
    }
    
    /// A component releases control of the audio session.
    func releaseSession(for client: AudioClient) {
        // Only deactivate if the calling client is the currently active one.
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
    
    private func setupMetronomePlayer() {
        guard let soundURL = Bundle.main.url(forResource: "tick", withExtension: "wav") else {
            print("Could not find the sound file 'tick.wav' in the bundle.")
            return
        }
        do {
            metronomePlayer = try AVAudioPlayer(contentsOf: soundURL)
            metronomePlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize metronome player: \(error.localizedDescription)")
        }
    }
    
    func playMetronomeTick() {
        // The metronome is a special case. It needs to play a sound without
        // taking permanent control of the session if another client (like the recorder)
        // is already active.
        if activeClient == .metronome || activeClient == .recorder {
            metronomePlayer?.currentTime = 0
            metronomePlayer?.play()
        } else {
            print("AudioManager: Metronome tick suppressed by active client: \(String(describing: activeClient))")
        }
    }
}
