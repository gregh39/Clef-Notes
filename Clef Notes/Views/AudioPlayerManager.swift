import SwiftUI
import SwiftData
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var currentlyPlayingID: PersistentIdentifier? = nil
    @Published var currentTime: TimeInterval = 0
    
    var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    
    private var audioManager: AudioManager

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }

    // --- THIS IS THE FIX ---
    // The play function now accepts the raw Data of the recording.
    func play(data: Data, id: PersistentIdentifier) {
        let hasSession = audioManager.requestSession(for: .player, category: .playback)
        guard hasSession else {
            print("AudioPlayerManager: Failed to acquire audio session.")
            return
        }
        
        do {
            audioPlayer?.stop()
            progressTimer?.invalidate()
            
            // AVAudioPlayer can be initialized directly from Data.
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.currentTime = 0
            audioPlayer?.play()
            
            currentTime = 0
            currentlyPlayingID = id

            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer, player.isPlaying else {
                    return
                }
                self.currentTime = player.currentTime
            }
        } catch {
            print("Playback failed: \(error.localizedDescription)")
            audioManager.releaseSession(for: .player)
        }
    }

    func stop() {
        audioPlayer?.stop()
        progressTimer?.invalidate()
        currentTime = 0
        currentlyPlayingID = nil
        audioManager.releaseSession(for: .player)
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    deinit {
        progressTimer?.invalidate()
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        progressTimer?.invalidate()
        currentTime = 0
        currentlyPlayingID = nil
        audioManager.releaseSession(for: .player)
    }
}
