import SwiftUI
import AVFoundation
import Combine

// An enum to manage the tuner state
private enum TunerMode: String, CaseIterable, Identifiable {
    case listening = "Listening"
    case drone = "Drone"
    var id: String { self.rawValue }
}

// This is a wrapper view that correctly initializes the StateObjects
// using the audioManager from the environment.
struct TunerTabView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        TunerTabContentView(audioManager: audioManager)
            .environmentObject(settingsManager)
    }
}

private struct TunerTabContentView: View {
    @StateObject private var droneViewModel: TunerViewModel
    @StateObject private var pitchTunerViewModel: PitchTunerViewModel
    
    @State private var tunerMode: TunerMode = .listening
    
    init(audioManager: AudioManager) {
        _droneViewModel = StateObject(wrappedValue: TunerViewModel(audioManager: audioManager))
        _pitchTunerViewModel = StateObject(wrappedValue: PitchTunerViewModel(audioManager: audioManager))
    }

    var body: some View {
        VStack {
            Picker("Tuner Mode", selection: $tunerMode) {
                ForEach(TunerMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if tunerMode == .listening {
                PitchListeningView(tuner: pitchTunerViewModel)
            } else {
                DroneView(viewModel: droneViewModel)
            }
        }
        .onDisappear {
            // Stop both engines when the view disappears
            droneViewModel.stopAll()
            pitchTunerViewModel.stop()
        }
        .onChange(of: tunerMode) {
            // Stop the inactive tuner to release audio resources
            if tunerMode == .listening {
                droneViewModel.stopAll()
            } else {
                pitchTunerViewModel.stop()
            }
        }
    }
}


// MARK: - Pitch Listening UI
private struct PitchListeningView: View {
    @ObservedObject var tuner: PitchTunerViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Play a note on your instrument...")
                .font(.headline)
                .foregroundColor(.secondary)

            // The main tuner display
            VStack {
                Text(tuner.detectedNoteName)
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                Text("\(tuner.detectedFrequency, specifier: "%.1f") Hz")
                    .font(.title2)
            }
            .padding(.vertical, 40)

            // Visual feedback meter
            TunerMeter(distance: $tuner.distance)

            Spacer()
                           
            SaveButtonView(title: tuner.isListening ? "Stop" : "Start Listening", action: {
                
                if tuner.isListening {
                    tuner.stop()
                } else {
                    tuner.start()
                }

            })
             /*
            Button(tuner.isListening ? "Stop" : "Start Listening") {
                            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tuner.isListening ? .red : .accentColor)
            .padding(.bottom, 40)*/
        }
    }
}

private struct TunerMeter: View {
    @Binding var distance: Double
    
    private var isPerfectTune: Bool { abs(distance) < 0.05 }

    var body: some View {
        ZStack(alignment: .center) {
            Capsule()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 30)
                .overlay(Capsule().stroke(Color.gray.opacity(0.4), lineWidth: 1))
            
            Rectangle()
                .fill(isPerfectTune ? .green : Color.accentColor)
                .frame(width: 4, height: 40)
                .offset(x: CGFloat(distance) * 150)
                .animation(.spring(), value: distance)
                .shadow(radius: 3)
            
            Rectangle()
                .fill(.green.opacity(0.5))
                .frame(width: 2, height: 30)
        }
        .padding()
    }
}

// MARK: - Drone Tone UI
private struct DroneView: View {
    @ObservedObject var viewModel: TunerViewModel
    @State private var selectedOctave: Int = 4

    var body: some View {
        VStack {
            Picker("Octave", selection: $selectedOctave) {
                ForEach(2...5, id: \.self) { octave in
                    Text("Octave \(octave)").tag(octave)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(TunerViewModel.availableNotes(for: selectedOctave)) { note in
                    Button(action: {
                        viewModel.selectedNote = note
                    }) {
                        Text(note.name)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(viewModel.selectedNote.name == note.name ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(viewModel.selectedNote.name == note.name ? Color.accentColor : Color.secondary, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("Volume")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.droneVolume, in: 0...1)
            }
            .padding(.horizontal)

            Spacer()
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.accentColor.opacity(viewModel.isPlayingDrone ? 0.5 : 0))
                    .scaleEffect(viewModel.isPlayingDrone ? 1.2 : 1.0)
                    .animation(viewModel.isPlayingDrone ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default, value: viewModel.isPlayingDrone)

                VStack {
                    Text("Drone Tone").font(.largeTitle).bold()
                    Text("\(viewModel.selectedNote.name): \(viewModel.targetFrequency, specifier: "%.1f") Hz")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            SaveButtonView(title: viewModel.isPlayingDrone ? "Stop" : "Start", action: {
                
                viewModel.toggleDrone()

            })

/*
            Button {
                viewModel.toggleDrone()
            } label: {
                Label(viewModel.isPlayingDrone ? "Stop" : "Start", systemImage: viewModel.isPlayingDrone ? "stop.circle.fill" : "play.circle.fill")
                    .frame(maxWidth: 250)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(viewModel.isPlayingDrone ? .red : .accentColor)
            .padding(.bottom, 40)
 */
        }
        .onChange(of: selectedOctave) { _, newOctave in
            let currentNoteName = viewModel.selectedNote.name
            let baseName = currentNoteName.trimmingCharacters(in: .decimalDigits)
            let newNotes = TunerViewModel.availableNotes(for: newOctave)
            if let newNote = newNotes.first(where: { $0.name.starts(with: baseName) }) {
                viewModel.selectedNote = newNote
            } else {
                viewModel.selectedNote = newNotes[9] // Fallback to 'A'
            }
        }
    }
}

// MARK: - Drone ViewModel and Helpers

struct TuningNote: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let frequency: Double
}

class TunerViewModel: ObservableObject {
    @Published var isPlayingDrone = false
    @Published var selectedNote: TuningNote = TunerViewModel.availableNotes(for: 4)[9]
    @Published var droneVolume: Float = 1.0 {
        didSet {
            if isEngineSetup {
                droneMixerNode.outputVolume = isPlayingDrone ? droneVolume : 0.0
            }
        }
    }
    
    var audioManager: AudioManager
    
    private var audioEngine: AVAudioEngine
    private var dronePlayerNode: AVAudioSourceNode?
    private var droneMixerNode: AVAudioMixerNode
    private var phase: Float = 0
    private var isEngineSetup = false
    
    var targetFrequency: Double { selectedNote.frequency }

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        self.audioEngine = AVAudioEngine()
        self.droneMixerNode = AVAudioMixerNode()
    }
    
    static func availableNotes(for octave: Int) -> [TuningNote] {
        let namesAndFreqs = [
            ("C", 16.35), ("C# / Db", 17.32), ("D", 18.35), ("D# / Eb", 19.45),
            ("E", 20.60), ("F", 21.83), ("F# / Gb", 23.12), ("G", 24.50),
            ("G# / Ab", 25.96), ("A", 27.50), ("A# / Bb", 29.14), ("B", 30.87)
        ]
        
        return namesAndFreqs.map { name, baseFreq in
            let frequency = baseFreq * pow(2.0, Double(octave))
            return TuningNote(name: "\(name)\(octave)", frequency: frequency)
        }
    }

    func toggleDrone() {
        if isPlayingDrone {
            droneMixerNode.outputVolume = 0.0
            stopEngineIfNeeded()
            isPlayingDrone = false
            audioManager.releaseSession(for: .tuner)
        } else {
            let hasSession = audioManager.requestSession(for: .tuner, category: .playback)
            guard hasSession else { return }
            
            startEngine()
            droneMixerNode.outputVolume = droneVolume
            isPlayingDrone = true
        }
    }

    func stopAll() {
        if isPlayingDrone {
            if audioEngine.isRunning {
                droneMixerNode.outputVolume = 0.0
                audioEngine.stop()
            }
            isPlayingDrone = false
            audioManager.releaseSession(for: .tuner)
        }
    }
    
    private func startEngine() {
        if !isEngineSetup {
            setupDroneNode()
            isEngineSetup = true
        }

        guard !audioEngine.isRunning else { return }
        do {
            try audioEngine.start()
        } catch {
            print("Could not start audio engine: \(error.localizedDescription)")
        }
    }

    private func stopEngineIfNeeded() {
        if !isPlayingDrone && audioEngine.isRunning {
            audioEngine.stop()
        }
    }

    private func setupDroneNode() {
        let format = audioEngine.outputNode.outputFormat(forBus: 0)
        
        dronePlayerNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            
            let frequency = Float(self.targetFrequency)
            let amplitude: Float = 0.5
            let sampleRate = Float(format.sampleRate)
            
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for frame in 0..<Int(frameCount) {
                let value = sin(2.0 * .pi * self.phase) * amplitude
                self.phase += frequency / sampleRate
                if self.phase >= 1.0 { self.phase -= 1.0 }
                
                for buffer in abl {
                    let typedBuffer = buffer.mData!.assumingMemoryBound(to: Float.self)
                    typedBuffer[frame] = value
                }
            }
            return noErr
        }
        
        audioEngine.attach(dronePlayerNode!)
        audioEngine.attach(droneMixerNode)
        
        audioEngine.connect(dronePlayerNode!, to: droneMixerNode, format: format)
        audioEngine.connect(droneMixerNode, to: audioEngine.mainMixerNode, format: format)
        
        droneMixerNode.outputVolume = 0.0
    }
}
