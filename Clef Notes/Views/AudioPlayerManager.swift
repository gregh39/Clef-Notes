import SwiftUI
import CoreData
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var currentlyPlayingID: NSManagedObjectID? = nil
    @Published var currentTime: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var playbackRate: Float = 1.0 // Speed: 0.5x to 2.0x

    // A-B Loop properties
    @Published var loopA: TimeInterval? = nil
    @Published var loopB: TimeInterval? = nil
    @Published var isLooping: Bool = false

    var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    private var audioManager: AudioManager

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        super.init()
    }

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
            audioPlayer?.enableRate = true // Enable speed control
            audioPlayer?.rate = playbackRate // Apply current playback rate
            audioPlayer?.currentTime = 0
            audioPlayer?.play()

            currentTime = 0
            currentlyPlayingID = id
            isPlaying = true

            startProgressTimer()
        } catch {
            print("Playback failed: \(error.localizedDescription)")
            audioManager.releaseSession(for: .player)
        }
    }

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer, player.isPlaying else {
                return
            }
            self.currentTime = player.currentTime

            // Check A-B loop
            if self.isLooping, let loopA = self.loopA, let loopB = self.loopB {
                if self.currentTime >= loopB {
                    player.currentTime = loopA
                    self.currentTime = loopA
                }
            }
        }
    }

    func stop() {
        audioPlayer?.stop()
        progressTimer?.invalidate()
        currentTime = 0
        currentlyPlayingID = nil
        isPlaying = false
        audioManager.releaseSession(for: .player)
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func skipBackward(seconds: TimeInterval = 5.0) {
        let newTime = max(0, currentTime - seconds)
        seek(to: newTime)
    }

    func skipForward(seconds: TimeInterval = 5.0) {
        guard let duration = audioPlayer?.duration else { return }
        let newTime = min(duration, currentTime + seconds)
        seek(to: newTime)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = max(0.5, min(2.0, rate)) // Clamp between 0.5x and 2.0x
        audioPlayer?.rate = playbackRate
    }

    // MARK: - A-B Loop Functions

    func setLoopA() {
        loopA = currentTime
        // If we have both points and they're in wrong order, swap them
        if let a = loopA, let b = loopB, a > b {
            loopA = b
            loopB = a
        }
    }

    func setLoopB() {
        loopB = currentTime
        // If we have both points and they're in wrong order, swap them
        if let a = loopA, let b = loopB, a > b {
            loopA = b
            loopB = a
        }
    }

    func clearLoop() {
        loopA = nil
        loopB = nil
        isLooping = false
    }

    func toggleLoop() {
        guard loopA != nil, loopB != nil else { return }
        isLooping.toggle()
    }

    var duration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }

    var hasLoopPoints: Bool {
        return loopA != nil && loopB != nil
    }

    deinit {
        progressTimer?.invalidate()
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // If looping, restart from loop A, otherwise finish normally
        if isLooping, let loopA = loopA {
            player.currentTime = loopA
            player.play()
            currentTime = loopA
        } else {
            progressTimer?.invalidate()
            currentTime = 0
            currentlyPlayingID = nil
            isPlaying = false
            audioManager.releaseSession(for: .player)
        }
    }
}
