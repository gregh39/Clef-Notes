// Clef Notes/Views/MetronomeEngine.swift

import Foundation
import AVFoundation
import Combine

/// Sample-accurate metronome.
///
/// Clicks are scheduled on an `AVAudioPlayerNode` at exact sample positions a short time
/// ahead of playback (a "lookahead" scheduler). Beat timing therefore comes from the audio
/// hardware clock rather than from `Timer`/run-loop callbacks, so it doesn't drift and
/// keeps going while the UI is busy (e.g. while the tempo slider is being dragged).
///
/// The owner is responsible for acquiring the audio session (via `AudioManager`) before
/// calling `start()`.
@MainActor
final class MetronomeEngine: ObservableObject {

    /// 1-based beat within the bar that is currently sounding; 0 when stopped.
    @Published private(set) var currentBeat = 0
    /// Increments on every audible click. Observe this to drive per-beat animations.
    @Published private(set) var beatPulse = 0
    @Published private(set) var isRunning = false

    /// Published so the metronome screen and the practice bar stay in sync across reopenings.
    @Published var bpm: Double = 60 {
        didSet {
            let bpm = bpm
            scheduler.update { $0.bpm = bpm }
        }
    }
    var beatsPerBar: Int = 4 {
        didSet { scheduler.update { $0.beatsPerBar = max(1, self.beatsPerBar) } }
    }
    var accentDownbeat: Bool = true {
        didSet { scheduler.update { $0.accentDownbeat = self.accentDownbeat } }
    }

    /// Seconds between beats at the current tempo.
    var beatInterval: TimeInterval { 60.0 / bpm }

    private let scheduler: ClickScheduler

    init() {
        scheduler = ClickScheduler()
        scheduler.onBeat = { [weak self] beat in
            guard let self, self.isRunning else { return }
            self.currentBeat = beat
            self.beatPulse &+= 1
        }
    }

    /// Starts clicking. Returns false if the audio engine could not be started.
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        let bpm = bpm, beats = beatsPerBar, accent = accentDownbeat
        scheduler.update {
            $0.bpm = bpm
            $0.beatsPerBar = max(1, beats)
            $0.accentDownbeat = accent
        }
        guard scheduler.start() else { return false }
        isRunning = true
        return true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        currentBeat = 0
        scheduler.stop()
    }
}

// MARK: - Scheduler

/// Owns the audio graph and performs all scheduling on a private serial queue.
/// Every mutable property is only touched on `queue`.
private final class ClickScheduler: @unchecked Sendable {

    struct Parameters {
        var bpm: Double = 60
        var beatsPerBar: Int = 4
        var accentDownbeat: Bool = true
    }

    /// Called on the main actor when a beat becomes audible, with the 1-based beat number.
    var onBeat: (@MainActor (Int) -> Void)?

    private let queue = DispatchQueue(label: "com.clefnotesapp.metronome", qos: .userInteractive)
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var clickBuffer: AVAudioPCMBuffer?
    private var accentBuffer: AVAudioPCMBuffer?
    private var format: AVAudioFormat?

    private var params = Parameters()
    private var timer: DispatchSourceTimer?
    private var running = false

    /// Player-timeline sample position of the next beat that has not been scheduled yet.
    private var nextBeatSample: AVAudioFramePosition = 0
    /// 0-based index within the bar of the next beat to schedule.
    private var nextBeatIndex = 0

    /// How far ahead of the playhead beats are scheduled.
    private let lookahead: TimeInterval = 0.15
    /// How often the scheduler tops up the queue.
    private let tickInterval: DispatchTimeInterval = .milliseconds(20)
    /// Small delay before the first beat so it is never scheduled in the past.
    private let startLead: TimeInterval = 0.05

    private var observers: [NSObjectProtocol] = []

    init() {
        loadBuffers()
        if let format {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            // The engine stops itself when the route/format changes (e.g. headphones, or the
            // recorder switching the session category). Restart and carry on from the next beat.
            self?.queue.async { self?.restartAfterInterruption() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: nil) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            self?.queue.async { self?.restartAfterInterruption() }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        timer?.cancel()
        engine.stop()
    }

    // MARK: Public (called from main)

    func update(_ change: @escaping (inout Parameters) -> Void) {
        queue.async { change(&self.params) }
    }

    func start() -> Bool {
        queue.sync {
            guard !running else { return true }
            guard clickBuffer != nil, accentBuffer != nil else { return false }
            guard startEngineAndPlayer() else { return false }
            running = true
            nextBeatIndex = 0

            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: tickInterval, leeway: .milliseconds(2))
            timer.setEventHandler { [weak self] in self?.scheduleAhead() }
            self.timer = timer
            timer.resume()
            return true
        }
    }

    func stop() {
        queue.async {
            self.running = false
            self.timer?.cancel()
            self.timer = nil
            self.player.stop()
            self.engine.stop()
        }
    }

    // MARK: Engine

    /// (Re)starts the engine and player; the player's timeline restarts at sample 0.
    private func startEngineAndPlayer() -> Bool {
        do {
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
        } catch {
            print("MetronomeEngine: failed to start audio engine: \(error)")
            return false
        }
        player.stop()   // flushes anything previously scheduled
        player.play()
        nextBeatSample = frames(for: startLead)
        return true
    }

    private func restartAfterInterruption() {
        guard running else { return }
        _ = startEngineAndPlayer()
    }

    // MARK: Scheduling

    private func scheduleAhead() {
        guard running, engine.isRunning,
              let clickBuffer, let accentBuffer, let format else { return }

        let sampleRate = format.sampleRate
        let now = currentPlayerSample() ?? 0
        let horizon = now + frames(for: lookahead)
        let interval = max(1, AVAudioFramePosition((60.0 / params.bpm) * sampleRate))

        // If we fell behind (e.g. the app was suspended), jump forward instead of
        // bursting a pile of late clicks.
        if nextBeatSample < now {
            let missed = (now - nextBeatSample) / interval + 1
            nextBeatSample += missed * interval
            nextBeatIndex = (nextBeatIndex + Int(missed)) % max(1, params.beatsPerBar)
        }

        let latency = AVAudioSession.sharedInstance().outputLatency

        while nextBeatSample < horizon {
            let beatIndex = nextBeatIndex % max(1, params.beatsPerBar)
            let buffer = (beatIndex == 0 && params.accentDownbeat) ? accentBuffer : clickBuffer
            let when = AVAudioTime(sampleTime: nextBeatSample, atRate: sampleRate)
            player.scheduleBuffer(buffer, at: when, options: [], completionHandler: nil)

            // Fire the UI callback when this click actually reaches the speaker.
            let delay = Double(nextBeatSample - now) / sampleRate + latency
            let beatNumber = beatIndex + 1
            let onBeat = self.onBeat
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay)) {
                MainActor.assumeIsolated { onBeat?(beatNumber) }
            }

            nextBeatSample += interval
            nextBeatIndex = (beatIndex + 1) % max(1, params.beatsPerBar)
        }
    }

    /// Current playhead position in the player's timeline, if the engine has rendered yet.
    private func currentPlayerSample() -> AVAudioFramePosition? {
        guard let nodeTime = player.lastRenderTime, nodeTime.isSampleTimeValid,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return nil }
        return playerTime.sampleTime
    }

    private func frames(for seconds: TimeInterval) -> AVAudioFramePosition {
        AVAudioFramePosition(seconds * (format?.sampleRate ?? 48_000))
    }

    // MARK: Buffers

    private func loadBuffers() {
        guard let clickURL = Bundle.main.url(forResource: "tick", withExtension: "wav"),
              let accentURL = Bundle.main.url(forResource: "tick_down", withExtension: "wav") else {
            print("MetronomeEngine: missing tick.wav / tick_down.wav in bundle")
            return
        }
        guard let click = Self.readBuffer(from: clickURL) else { return }
        format = click.format
        clickBuffer = click
        accentBuffer = Self.readBuffer(from: accentURL).flatMap { Self.convert($0, to: click.format) }
    }

    private static func readBuffer(from url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            print("MetronomeEngine: failed to read \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    /// Returns `buffer` in `format`, converting only if the formats differ.
    private static func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .endOfStream
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if let error {
            print("MetronomeEngine: failed to convert click buffer: \(error)")
            return nil
        }
        return output
    }
}
