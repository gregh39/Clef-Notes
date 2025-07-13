import SwiftUI
import AVFoundation

struct TuningNote: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let frequency: Double
}

struct TunerTabView: View {
    @EnvironmentObject var audioManager: AudioManager
    
    // --- THIS IS THE FIX ---
    // For classes using the @Observable macro, @State is the correct
    // property wrapper for instantiation and ownership in a view.
    @State private var viewModel: TunerViewModel
    
    @State private var selectedOctave: Int = 4
    
    init() {
        // The initializer now uses @State's syntax.
        _viewModel = State(initialValue: TunerViewModel(audioManager: AudioManager()))
    }

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
                            .background(viewModel.selectedNote == note ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(viewModel.selectedNote == note ? Color.accentColor : Color.secondary, lineWidth: 1)
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
                    .foregroundColor(.blue.opacity(viewModel.isPlayingDrone ? 0.5 : 0))
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
        }
        .onAppear {
            // This ensures the viewModel uses the single, shared instance of AudioManager.
            viewModel.audioManager = audioManager
        }
        .onDisappear {
            viewModel.stopAll()
        }
        .onChange(of: selectedOctave) { _, newValue in
            viewModel.selectedNote = TunerViewModel.availableNotes(for: newValue)[9] // Default to A
        }
    }
}

@MainActor
@Observable
class TunerViewModel {
    var audioManager: AudioManager
    
    private var audioEngine: AVAudioEngine
    private var dronePlayerNode: AVAudioSourceNode?
    private var droneMixerNode: AVAudioMixerNode
    private var phase: Float = 0
    
    var isPlayingDrone = false
    var droneVolume: Float = 1.0 {
        didSet {
            droneMixerNode.outputVolume = isPlayingDrone ? droneVolume : 0.0
        }
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
    
    var selectedNote: TuningNote = TunerViewModel.availableNotes(for: 4)[9]
    var targetFrequency: Double { selectedNote.frequency }

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        self.audioEngine = AVAudioEngine()
        self.droneMixerNode = AVAudioMixerNode()
        setupDroneNode()
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
            droneMixerNode.outputVolume = 0.0
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            isPlayingDrone = false
            audioManager.releaseSession(for: .tuner)
        }
    }
    
    private func startEngine() {
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
