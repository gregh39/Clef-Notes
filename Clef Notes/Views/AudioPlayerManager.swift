import SwiftUI
import CoreData
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    // --- CHANGE 1: The ID type is now NSManagedObjectID ---
    @Published var currentlyPlayingID: NSManagedObjectID? = nil
    @Published var currentTime: TimeInterval = 0
    
    var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    
    private var audioManager: AudioManager

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        super.init()
    }

    // --- CHANGE 2: The play function now accepts an NSManagedObjectID ---
    func play(data: Data, id: NSManagedObjectID) {
        let hasSession = audioManager.requestSession(for: .player, category: .playback)
        guard hasSession else {
            print("AudioPlayerManager: Failed to acquire audio session.")
            return
        }
        
        do {
            audioPlayer?.stop()
            progressTimer?.invalidate()
            
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
