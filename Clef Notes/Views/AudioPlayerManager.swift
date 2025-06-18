//
//  AudioPlayerManager.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/16/25.
//
import SwiftUI
import SwiftData
import AVFoundation
import PhotosUI
import Combine


class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var currentlyPlayingID: PersistentIdentifier? = nil
    @Published var currentTime: TimeInterval = 0
    var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    func play(url: URL, id: PersistentIdentifier) {
        do {
            audioPlayer?.stop()
            progressTimer?.invalidate()
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
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
        }
    }

    func stop() {
        audioPlayer?.stop()
        progressTimer?.invalidate()
        currentTime = 0
        currentlyPlayingID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        progressTimer?.invalidate()
        currentTime = 0
        currentlyPlayingID = nil
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    deinit {
        progressTimer?.invalidate()
    }
}
