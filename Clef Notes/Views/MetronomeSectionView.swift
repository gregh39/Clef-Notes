import SwiftUI
import AVFoundation

struct MetronomeSectionView: View {
    
    // MARK: - State Properties
    
    /// The tempo in beats per minute.
    @State private var bpm: Double = 120.0
    
    /// Indicates whether the metronome is currently running.
    @State private var isPlaying: Bool = false
    
    /// The timer that drives the metronome's beat.
    @State private var timer: Timer?
    
    /// The audio player for the tick sound.
    @State private var audioPlayer: AVAudioPlayer?

    /// State property to control the color of the pulsing visual.
    @State private var pulseColor: Color = .gray.opacity(0.3)

    // MARK: - Constants
    
    /// The valid range for the tempo.
    private let tempoRange: ClosedRange<Double> = 40...240

    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // --- Pulsing Circle Visual ---
            Circle()
                .fill(pulseColor)
                .frame(width: 200, height: 200)
            
            Spacer()
            
            // --- Controls ---
            VStack(spacing: 25) {
                // --- Tempo Controls ---
                HStack(spacing: 25) {
                    // --- Decrease Tempo Button ---
                    Button(action: {
                        if bpm > tempoRange.lowerBound {
                            bpm -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(bpm > tempoRange.lowerBound ? .blue : .gray)
                    }
                    .disabled(bpm <= tempoRange.lowerBound)
                    
                    // --- BPM Display ---
                    Text("\(Int(bpm)) BPM")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 130)

                    // --- Increase Tempo Button ---
                    Button(action: {
                        if bpm < tempoRange.upperBound {
                            bpm += 1
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(bpm < tempoRange.upperBound ? .blue : .gray)
                    }
                    .disabled(bpm >= tempoRange.upperBound)
                }
                .onChange(of: bpm) { newBpm in
                    // If playing, reschedule the timer to smoothly update the tempo.
                    if isPlaying {
                        rescheduleTimer(for: newBpm)
                    }
                }
                
                // --- Start/Stop Button ---
                Button(action: toggleMetronome) {
                    Label(isPlaying ? "Stop" : "Start", systemImage: isPlaying ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(isPlaying ? Color.red : Color.green)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGray6))
        .edgesIgnoringSafeArea(.bottom)
        .onAppear(perform: setupAudioPlayer)
    }

    // MARK: - Metronome Logic
    
    /// Toggles the metronome's playing state.
    private func toggleMetronome() {
        isPlaying.toggle()
        if isPlaying {
            startMetronome()
        } else {
            stopMetronome()
        }
    }

    /// Starts the metronome from a stopped state.
    private func startMetronome() {
        let timeInterval = 60.0 / bpm
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            self.performTick(with: timeInterval)
        }
        timer?.fire()
    }
    
    /// Reschedules the timer with a new tempo for a smooth transition.
    private func rescheduleTimer(for newBpm: Double) {
        timer?.invalidate()
        let timeInterval = 60.0 / newBpm
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            self.performTick(with: timeInterval)
        }
    }

    /// Stops the metronome timer and resets the visual.
    private func stopMetronome() {
        timer?.invalidate()
        timer = nil
        withAnimation {
            pulseColor = .gray.opacity(0.3)
        }
    }
    
    /// The action performed on each metronome tick: playing a sound and triggering the visual pulse.
    private func performTick(with timeInterval: TimeInterval) {
        playSound()
        
        // Trigger the pulse animation.
        // It quickly animates to full color...
        withAnimation(.easeOut(duration: 0.1)) {
            pulseColor = .blue
        }
        
        // ...then fades back over the remainder of the beat duration.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: timeInterval * 0.8)) {
                pulseColor = .gray.opacity(0.3)
            }
        }
    }

    // MARK: - Audio Logic

    /// Sets up the AVAudioPlayer with the "tick.wav" file from the app bundle.
    /// **Remember to add a "tick.wav" file to your project bundle.**
    private func setupAudioPlayer() {
        guard let soundURL = Bundle.main.url(forResource: "tick", withExtension: "wav") else {
            print("Could not find the sound file 'tick.wav' in the bundle.")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize or configure AVAudioPlayer: \(error.localizedDescription)")
        }
    }

    /// Plays the configured sound.
    private func playSound() {
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
}
