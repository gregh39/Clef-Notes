import SwiftUI
import AVFoundation

// MARK: - TuningNote Model
// A simple struct to represent a musical note with its name and frequency.
// It's Hashable to be used in SwiftUI Pickers.
struct TuningNote: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let frequency: Double
}

// MARK: - Drone Tuner Feature
struct TunerTabView: View {
    // For classes using the @Observable macro, @State is the correct
    // property wrapper to use for instantiation and ownership in a view.
    @State private var viewModel = TunerViewModel()
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
            
            // 4x3 Grid of note buttons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(TunerViewModel.availableNotes(for: selectedOctave)) { note in
                    Button(action: {
                        viewModel.selectedNote = note
                    }) {
                        Text(note.name)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(
                                viewModel.selectedNote.name == note.name && abs(viewModel.selectedNote.frequency - note.frequency) < 0.1
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        viewModel.selectedNote.name == note.name && abs(viewModel.selectedNote.frequency - note.frequency) < 0.1
                                            ? Color.accentColor
                                            : Color.secondary,
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("Volume")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { viewModel.droneVolume },
                    set: { viewModel.droneVolume = $0 }
                ), in: 0...1)
            }
            .padding(.horizontal)

            Spacer()
            
            ZStack {
                // A visual indicator that pulses when the drone is playing.
                Circle()
                    .stroke(lineWidth: 10)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue.opacity(viewModel.isPlayingDrone ? 0.5 : 0))
                    .scaleEffect(viewModel.isPlayingDrone ? 1.2 : 1.0)
                    .animation(
                        viewModel.isPlayingDrone ?
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                            .default,
                        value: viewModel.isPlayingDrone
                    )

                VStack {
                    // Display the target frequency (A4 = 440 Hz).
                    Text("Drone Tone")
                        .font(.largeTitle).bold()
                    
                    // Display the currently selected note and its frequency.
                    Text("\(viewModel.selectedNote.name): \(viewModel.targetFrequency, specifier: "%.1f") Hz")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()

            // Controls for the drone.
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
        .onDisappear {
            // Ensure audio engine stops when the view is no longer visible.
            viewModel.stopAll()
        }
        .onChange(of: selectedOctave) { _, newValue in
            viewModel.selectedNote = TunerViewModel.availableNotes(for: newValue)[9] // Default to A
        }
    }
}


@Observable
class TunerViewModel {
    private var audioEngine: AVAudioEngine
    private var dronePlayerNode: AVAudioSourceNode?
    private var droneMixerNode: AVAudioMixerNode // Mixer to control drone volume
    
    // MARK: - Published Properties for UI
    var isPlayingDrone = false
    
    var droneVolume: Float = 1.0 {
        didSet {
            droneMixerNode.outputVolume = isPlayingDrone ? droneVolume : 0.0
        }
    }
    
    /// The list of notes available for the user to select.
    static func availableNotes(for octave: Int) -> [TuningNote] {
        let namesAndFreqs = [
            ("C", 16.35), ("C# / Db", 17.32), ("D", 18.35), ("D# / Eb", 19.45),
            ("E", 20.60), ("F", 21.83), ("F# / Gb", 23.12), ("G", 24.50),
            ("G# / Ab", 25.96), ("A", 27.50), ("A# / Bb", 29.14), ("B", 30.87)
        ]
        
        return namesAndFreqs.enumerated().map { index, pair in
            let (name, baseFreq) = pair
            let frequency = baseFreq * pow(2.0, Double(octave))
            return TuningNote(name: "\(name)\(octave)", frequency: frequency)
        }
    }
    
    /// The currently selected note, defaulting to A4.
    var selectedNote: TuningNote = TunerViewModel.availableNotes(for: 4)[9]
    
    /// The target frequency is now a computed property based on the selected note.
    var targetFrequency: Double {
        selectedNote.frequency
    }

    init() {
        self.audioEngine = AVAudioEngine()
        self.droneMixerNode = AVAudioMixerNode()
        setupAudioSession()
        setupDroneNode()
    }

    // MARK: - Public Control Methods
    
    /// Toggles the drone sound on and off by changing the mixer volume.
    func toggleDrone() {
        if isPlayingDrone {
            droneMixerNode.outputVolume = 0.0 // Mute the drone
            stopEngineIfNeeded()
            isPlayingDrone = false
        } else {
            startEngine()
            droneMixerNode.outputVolume = droneVolume // Unmute the drone with current volume
            isPlayingDrone = true
        }
    }

    /// Stops all audio processing. Called when the view disappears.
    func stopAll() {
        droneMixerNode.outputVolume = 0.0 // Mute the drone
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        isPlayingDrone = false
    }

    // MARK: - Audio Engine Setup & Control
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Configure the session for playback only.
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // Use do-catch for better error reporting instead of try?
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }

    private func startEngine() {
        guard !audioEngine.isRunning else { return }
        do {
            try audioEngine.start()
        } catch {
            // Use do-catch for better error reporting.
            print("Could not start audio engine: \(error.localizedDescription)")
        }
    }

    /// Stops the engine only if it's not needed.
    private func stopEngineIfNeeded() {
        if !isPlayingDrone && audioEngine.isRunning {
            audioEngine.stop()
        }
    }

    // MARK: - Drone Generation Logic
    
    private func setupDroneNode() {
        let format = audioEngine.outputNode.outputFormat(forBus: 0)
        
        // This node generates a continuous sine wave.
        dronePlayerNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            
            // Define constants for clarity. The frequency now comes from the computed property.
            let frequency = Float(self.targetFrequency)
            let amplitude: Float = 0.5
            let sampleRate = Float(format.sampleRate)
            
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            // Generate a sine wave programmatically.
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
        
        // Start with the drone muted.
        droneMixerNode.outputVolume = 0.0
    }
    private var phase: Float = 0
}

