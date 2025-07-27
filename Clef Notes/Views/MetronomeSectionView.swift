import SwiftUI
import AVFoundation

private enum MetronomeVisualizerType: String, CaseIterable, Identifiable {
    case pulse = "Pulse"
    case arm = "Swinging Arm"
    var id: String { self.rawValue }
}

private struct TimeSignature: Hashable, Identifiable {
    let id: String
    let beats: Int
    let noteValue: Int
    
    var description: String { "\(beats)/\(noteValue)" }
    
    init(beats: Int, noteValue: Int) {
        self.id = "\(beats)/\(noteValue)"
        self.beats = beats
        self.noteValue = noteValue
    }
    
    static let all: [TimeSignature] = [
        .init(beats: 1, noteValue: 4), .init(beats: 2, noteValue: 4), .init(beats: 3, noteValue: 4),
        .init(beats: 4, noteValue: 4), .init(beats: 5, noteValue: 4), .init(beats: 6, noteValue: 4),
        .init(beats: 3, noteValue: 8), .init(beats: 5, noteValue: 8), .init(beats: 6, noteValue: 8),
        .init(beats: 7, noteValue: 8), .init(beats: 9, noteValue: 8), .init(beats: 12, noteValue: 8)
    ]
}

struct MetronomeSectionView: View {
    @EnvironmentObject var audioManager: AudioManager
    @AppStorage("selectedAccentColor") private var accentColor: AccentColor = .blue
    
    @AppStorage("metronomeVisualizerType") private var visualizerType: MetronomeVisualizerType = .pulse
    @AppStorage("metronomeTimeSignatureID") private var timeSignatureID: String = "4/4"
    // --- THIS IS THE FIX: AppStorage to save the user's downbeat preference ---
    @AppStorage("metronomeHighlightDownbeat") private var highlightDownbeat: Bool = true

    @State private var bpm: Double = 60.0
    @State private var isPlaying: Bool = false
    @State private var timer: Timer?
    @State private var beatCount: Int = 0
    
    @State private var showingTimeSignatureSheet = false
    
    @State private var pulseRadius: CGFloat = 0
    @State private var armRotation: Double = -45

    private let tempoRange: ClosedRange<Double> = 40...240
    private var selectedTimeSignature: TimeSignature {
        TimeSignature.all.first { $0.id == timeSignatureID } ?? .init(beats: 4, noteValue: 4)
    }

    var body: some View {
        VStack {
            // --- THIS IS THE FIX: Grouped the metronome settings ---
            VStack(spacing: 12) {
                Picker("Visualizer", selection: $visualizerType) {
                    ForEach(MetronomeVisualizerType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                
                Toggle("Highlight Downbeat", isOn: $highlightDownbeat)
            }
            .padding(.horizontal)

            Spacer()
            
            ZStack {
                switch visualizerType {
                case .pulse:
                    PulseVisualizer(pulseRadius: $pulseRadius, beatCount: $beatCount, accentColor: accentColor.color, highlightDownbeat: highlightDownbeat)
                case .arm:
                    MetronomeArmView(rotation: $armRotation, beatCount: $beatCount, highlightDownbeat: highlightDownbeat)
                }
            }
            .frame(height: 300)
            
            Spacer()
            
            VStack {
                Button {
                    showingTimeSignatureSheet = true
                } label: {
                    VStack {
                        Text("Time Signature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selectedTimeSignature.description)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor.color)
                    }
                }
                .padding(.bottom)

                HStack {
                    Button(action: { if bpm > tempoRange.lowerBound { bpm -= 1 } }) {
                        Image(systemName: "minus.circle.fill")
                    }
                    .font(.system(size: 40))
                    .foregroundColor(bpm > tempoRange.lowerBound ? accentColor.color : .gray)
                    .disabled(bpm <= tempoRange.lowerBound)
                    
                    Text("\(Int(bpm)) BPM")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 130)

                    Button(action: { if bpm < tempoRange.upperBound { bpm += 1 } }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .font(.system(size: 40))
                    .foregroundColor(bpm < tempoRange.upperBound ? accentColor.color : .gray)
                    .disabled(bpm >= tempoRange.upperBound)
                }
                .onChange(of: bpm) {
                    if isPlaying { rescheduleTimer(for: bpm) }
                }
                
                Slider(value: $bpm, in: tempoRange, step: 1)
                    .tint(accentColor.color)
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
            .tint(isPlaying ? .red : accentColor.color)
            .padding(.bottom, 40)
        }
        .onDisappear(perform: stopMetronome)
        .sheet(isPresented: $showingTimeSignatureSheet) {
            TimeSignatureSelectionSheet(selectedID: $timeSignatureID)
                .presentationDetents([.medium])
        }
    }

    private func toggleMetronome() {
        isPlaying.toggle()
        if isPlaying {
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
        beatCount = 0
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
        beatCount = 0
        withAnimation {
            pulseRadius = 0
            armRotation = -45
        }
        audioManager.releaseSession(for: .metronome)
    }
    
    private func performTick(with timeInterval: TimeInterval) {
        beatCount = (beatCount % selectedTimeSignature.beats) + 1
        
        // --- THIS IS THE FIX: Check the highlightDownbeat flag before playing the sound ---
        if beatCount == 1 && highlightDownbeat {
            audioManager.playMetronomeDownbeat()
        } else {
            audioManager.playMetronomeUpbeat()
        }
        
        switch visualizerType {
        case .pulse:
            withAnimation(.easeOut(duration: 0.1)) {
                pulseRadius = 150
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeIn(duration: timeInterval * 0.8)) {
                    pulseRadius = 0
                }
            }
        case .arm:
            let targetRotation = armRotation > 0 ? -45.0 : 45.0
            withAnimation(.easeInOut(duration: timeInterval)) {
                armRotation = targetRotation
            }
        }
    }
}

private struct TimeSignatureSelectionSheet: View {
    @Binding var selectedID: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedAccentColor") private var accentColor: AccentColor = .blue
    
    private let commonTime = TimeSignature.all.filter { $0.noteValue == 4 }
    private let compoundTime = TimeSignature.all.filter { $0.noteValue == 8 }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select a Time Signature")
                        .font(.largeTitle.bold())
                        .padding(.horizontal)

                    SignatureGroupView(title: "Common Time", signatures: commonTime, selectedID: $selectedID)
                    SignatureGroupView(title: "Compound Time", signatures: compoundTime, selectedID: $selectedID)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private struct SignatureGroupView: View {
        let title: String
        let signatures: [TimeSignature]
        @Binding var selectedID: String
        @AppStorage("selectedAccentColor") private var accentColor: AccentColor = .blue

        var body: some View {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                    ForEach(signatures) { signature in
                        Button {
                            selectedID = signature.id
                        } label: {
                            Text(signature.description)
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(selectedID == signature.id ? accentColor.color : Color(UIColor.secondarySystemGroupedBackground))
                                .foregroundColor(selectedID == signature.id ? .white : .primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}


private struct PulseVisualizer: View {
    @Binding var pulseRadius: CGFloat
    @Binding var beatCount: Int
    let accentColor: Color
    // --- THIS IS THE FIX: Added property to control highlighting ---
    let highlightDownbeat: Bool
    
    private var isDownbeat: Bool { beatCount == 1 && highlightDownbeat }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    // --- THIS IS THE FIX: Color depends on the isDownbeat check ---
                    gradient: Gradient(colors: [isDownbeat ? .red : accentColor, .clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: pulseRadius
                )
            )
            .frame(width: 300, height: 300)
    }
}

private struct MetronomeArmView: View {
    @Binding var rotation: Double
    @Binding var beatCount: Int
    // --- THIS IS THE FIX: Added property to control highlighting ---
    let highlightDownbeat: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.5), lineWidth: 5)
                .frame(width: 250, height: 250)
            
            Capsule()
                .fill(Color.primary)
                .frame(width: 8, height: 150)
                .overlay(
                    Circle()
                        // --- THIS IS THE FIX: Color depends on the beat and the toggle ---
                        .fill((beatCount == 1 && highlightDownbeat) ? .red : .primary)
                        .frame(width: 30, height: 30)
                        .offset(y: -40)
                )
                .rotationEffect(.degrees(rotation), anchor: .bottom)
                .offset(y: -50)
            
            Circle()
                .fill(Color.primary)
                .frame(width: 20, height: 20)
        }
    }
}
