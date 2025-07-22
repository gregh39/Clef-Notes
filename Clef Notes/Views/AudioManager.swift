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
        
        if activeClient != nil && activeClient != client {
            print("AudioManager: Deactivating previous client (\(String(describing: activeClient))) for new client (\(client)).")
        }
        
        do {
            try session.setActive(false)
            try session.setCategory(category, mode: .default, options: options)
            try session.setActive(true)
            
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
}
