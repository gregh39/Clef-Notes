// Clef Notes/Views/MetronomeSectionView.swift

import SwiftUI
import AVFoundation
import TelemetryDeck

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
    @EnvironmentObject var settingsManager: SettingsManager // <<< USE THEME FROM ENVIRONMENT

    @AppStorage("metronomeVisualizerType") private var visualizerType: MetronomeVisualizerType = .pulse
    @AppStorage("metronomeTimeSignatureID") private var timeSignatureID: String = "4/4"
    @AppStorage("metronomeHighlightDownbeat") private var highlightDownbeat: Bool = true

    @State private var beatCount: Int = 0
    /// Shared engine, so tempo is remembered and it can keep playing after this screen closes.
    @ObservedObject private var engine = PracticeSessionManager.shared.metronome

    /// When false (practice bar sheet), the metronome keeps playing after this view goes away;
    /// the practice bar shows that it's on and can reopen it.
    var stopsOnDisappear: Bool = true

    private var isPlaying: Bool { engine.isRunning }
    
    @State private var showingTimeSignatureSheet = false
    
    @State private var pulseRadius: CGFloat = 0
    @State private var armRotation: Double = -45

    private let tempoRange: ClosedRange<Double> = 40...240
    private var selectedTimeSignature: TimeSignature {
        TimeSignature.all.first { $0.id == timeSignatureID } ?? .init(beats: 4, noteValue: 4)
    }

    var body: some View {
        VStack {
            Spacer()
            VStack() {
                Picker("Visualizer", selection: $visualizerType) {
                    ForEach(MetronomeVisualizerType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            Spacer()
            
            ZStack {
                switch visualizerType {
                case .pulse:
                    PulseVisualizer(pulseRadius: $pulseRadius, beatCount: $beatCount, accentColor: settingsManager.activeAccentColor, highlightDownbeat: highlightDownbeat)
                case .arm:
                    MetronomeArmView(rotation: $armRotation, beatCount: $beatCount, highlightDownbeat: highlightDownbeat)
                }
            }
           // .frame(height: 300)
            
            //Spacer()
            
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
                            .foregroundColor(settingsManager.activeAccentColor) // <<< USE THEME COLOR
                    }
                }
                .padding(.bottom)

                HStack {
                    Button(action: { if engine.bpm > tempoRange.lowerBound { engine.bpm -= 1 } }) {
                        Image(systemName: "minus.circle.fill")
                    }
                    .font(.system(size: 40))
                    .foregroundColor(engine.bpm > tempoRange.lowerBound ? settingsManager.activeAccentColor : .gray) // <<< USE THEME COLOR
                    .disabled(engine.bpm <= tempoRange.lowerBound)
                    
                    Text("\(Int(engine.bpm)) BPM")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 130)

                    Button(action: { if engine.bpm < tempoRange.upperBound { engine.bpm += 1 } }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .font(.system(size: 40))
                    .foregroundColor(engine.bpm < tempoRange.upperBound ? settingsManager.activeAccentColor : .gray) // <<< USE THEME COLOR
                    .disabled(engine.bpm >= tempoRange.upperBound)
                }

                // Tempo changes apply from the next unscheduled beat; no restart needed.
                Slider(value: $engine.bpm, in: tempoRange, step: 1)
                    .tint(settingsManager.activeAccentColor) // <<< USE THEME COLOR
                    .padding(.horizontal)
            }
            
            //Spacer()
            
            SaveButtonView(title: isPlaying ? "Stop" : "Start", action: {
                toggleMetronome()
            })
        }
        .navigationTitle("Metronome")
        .onAppear(perform: syncEngineSettings)
        .onChange(of: timeSignatureID) { syncEngineSettings() }
        .onChange(of: highlightDownbeat) { syncEngineSettings() }
        .onChange(of: engine.beatPulse) { animateBeat() }
        .onDisappear {
            if stopsOnDisappear { stopMetronome() }
        }
        .sheet(isPresented: $showingTimeSignatureSheet) {
            TimeSignatureSelectionSheet(selectedID: $timeSignatureID, highlightDownbeat: $highlightDownbeat)
                .presentationDetents([.medium])
        }
    }

    private func toggleMetronome() {
        if !isPlaying {
            let hasSession = audioManager.requestSession(for: .metronome, category: .playback, options: .mixWithOthers)
            guard hasSession else { return }
            TelemetryDeck.signal("metronome_started", parameters: ["bpm": "\(Int(engine.bpm))"])
            startMetronome()
        } else {
            TelemetryDeck.signal("metronome_stopped", parameters: ["bpm": "\(Int(engine.bpm))"])
            stopMetronome()
        }
    }

    private func syncEngineSettings() {
        engine.beatsPerBar = selectedTimeSignature.beats
        engine.accentDownbeat = highlightDownbeat
    }

    private func startMetronome() {
        beatCount = 0
        syncEngineSettings()
        if !engine.start() {
            audioManager.releaseSession(for: .metronome)
        }
    }

    private func stopMetronome() {
        engine.stop()
        beatCount = 0
        withAnimation {
            pulseRadius = 0
            armRotation = -45
        }
        audioManager.releaseSession(for: .metronome)
    }

    /// Runs when the engine reports that a click has become audible.
    private func animateBeat() {
        guard engine.isRunning else { return }
        beatCount = engine.currentBeat
        let timeInterval = engine.beatInterval

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
    @Binding var highlightDownbeat: Bool
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager // <<< USE THEME FROM ENVIRONMENT
    
    private let commonTime = TimeSignature.all.filter { $0.noteValue == 4 }
    private let compoundTime = TimeSignature.all.filter { $0.noteValue == 8 }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select a Time Signature")
                        .font(.largeTitle.bold())
                        .padding(.horizontal)
                    
                    Toggle("Highlight Downbeat", isOn: $highlightDownbeat)

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
        @EnvironmentObject var settingsManager: SettingsManager // <<< USE THEME FROM ENVIRONMENT

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
                                .background(selectedID == signature.id ? settingsManager.activeAccentColor : Color(UIColor.secondarySystemGroupedBackground)) // <<< USE THEME COLOR
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
    let highlightDownbeat: Bool
    
    private var isDownbeat: Bool { beatCount == 1 && highlightDownbeat }

    /// Radius of the pulse at full size; `pulseRadius` animates between 0 and this value.
    private let maxRadius: CGFloat = 150

    /// 0 at rest, 1 at the peak of a beat.
    private var progress: CGFloat { min(max(pulseRadius / maxRadius, 0), 1) }

    var body: some View {
        // The gradient itself stays fixed. Only scale and opacity change, because SwiftUI
        // animates those smoothly; animating the gradient's endRadius directly doesn't
        // interpolate and can leave a solid disc on screen.
        let color = isDownbeat ? Color.red : accentColor
        // EllipticalGradient sizes itself to the shape, so the glow can shrink to fit
        // smaller layouts (e.g. inside the session detail) without clipping.
        Circle()
            .fill(
                EllipticalGradient(
                    colors: [color, color.opacity(0)],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.5
                )
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: maxRadius * 2, maxHeight: maxRadius * 2)
            .scaleEffect(progress)
            .opacity(progress)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MetronomeArmView: View {
    @Binding var rotation: Double
    @Binding var beatCount: Int
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
