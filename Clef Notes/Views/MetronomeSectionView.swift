import SwiftUI
import AVFoundation

struct MetronomeSectionView: View {
    // Inject the AudioManager from the environment.
    @EnvironmentObject var audioManager: AudioManager
    
    @State private var bpm: Double = 60.0
    @State private var isPlaying: Bool = false
    @State private var timer: Timer?
    @State private var pulseRadius: CGFloat = 0
    
    private let tempoRange: ClosedRange<Double> = 40...240

    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                Circle()
                    .foregroundColor(.clear)
                    .background(
                        Circle()
                            .fill(RadialGradient(gradient: Gradient(colors: [.blue, .clear]), center: .center, startRadius: 0, endRadius: pulseRadius))
                            .frame(width: 300, height: 300)
                    )
                    .frame(width: 300, height: 300)
            }
            
            Spacer()
            
            VStack {
                HStack {
                    Button(action: { if bpm > tempoRange.lowerBound { bpm -= 1 } }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(bpm > tempoRange.lowerBound ? .blue : .gray)
                    }
                    .disabled(bpm <= tempoRange.lowerBound)
                    
                    Text("\(Int(bpm)) BPM")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 130)

                    Button(action: { if bpm < tempoRange.upperBound { bpm += 1 } }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(bpm < tempoRange.upperBound ? .blue : .gray)
                    }
                    .disabled(bpm >= tempoRange.upperBound)
                }
                .onChange(of: bpm) { oldBpm, newBpm in
                    if isPlaying {
                        rescheduleTimer(for: newBpm)
                    }
                }
                
                Slider(value: $bpm, in: tempoRange, step: 1) {
                    Text("Tempo")
                } minimumValueLabel: {
                    Text("\(Int(tempoRange.lowerBound))")
                } maximumValueLabel: {
                    Text("\(Int(tempoRange.upperBound))")
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            
            Spacer()
            Button(action: toggleMetronome) {
                Label(isPlaying ? "Stop" : "Start", systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .frame(maxWidth: 250)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isPlaying ? .red : .accentColor)
            .padding(.bottom, 40)
        }
        .onDisappear(perform: stopMetronome)
    }

    // MARK: - Metronome Logic
    
    private func toggleMetronome() {
        isPlaying.toggle()
        if isPlaying {
            // Request the session from the central manager.
            // .mixWithOthers allows it to play alongside other audio, like the recorder.
            let hasSession = audioManager.requestSession(for: .metronome, category: .playback, options: .mixWithOthers)
            guard hasSession else {
                isPlaying = false
                return
            }
            startMetronome()
        } else {
            stopMetronome()
        }
    }

    private func startMetronome() {
        let timeInterval = 60.0 / bpm
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            self.performTick(with: timeInterval)
        }
        timer?.fire()
    }
    
    private func rescheduleTimer(for newBpm: Double) {
        timer?.invalidate()
        let timeInterval = 60.0 / newBpm
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            self.performTick(with: timeInterval)
        }
    }

    private func stopMetronome() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
        withAnimation { pulseRadius = 10 }
        
        // Release the session via the central manager.
        audioManager.releaseSession(for: .metronome)
    }
    
    private func performTick(with timeInterval: TimeInterval) {
        // Play the sound via the central manager.
        audioManager.playMetronomeTick()
        
        withAnimation(.easeOut(duration: 0.1)) {
            pulseRadius = 150
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: timeInterval * 0.8)) {
                pulseRadius = 10
            }
        }
    }
}
