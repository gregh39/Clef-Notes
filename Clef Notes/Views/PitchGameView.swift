import SwiftUI

struct PitchGameView: View {
    @State private var viewModel: PitchGameViewModel
    @EnvironmentObject var audioManager: AudioManager

    init() {
        _viewModel = State(initialValue: PitchGameViewModel(audioManager: AudioManager()))
    }

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 20) {
            if !viewModel.isGameActive {
                startView
            } else if viewModel.isGameOver {
                gameOverView
            } else {
                gameplayView
            }
        }
        .padding()
        .navigationTitle("Pitch Perfect")
        .onAppear {
            viewModel.audioManager = audioManager
        }
    }
    
    private var startView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            Text("Pitch Perfect")
                .font(.largeTitle.bold())
            Text("Listen to the note, then choose the correct answer. See how many you can get right out of 10!")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Start Game", action: viewModel.startGame)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var gameplayView: some View {
        VStack(spacing: 20) {
            // Score and Progress
            HStack {
                Text("Score: \(viewModel.score)")
                Spacer()
                Text("Question: \(viewModel.questionsAsked) / 10")
            }
            .font(.headline.bold())

            Spacer()

            // "Play Note" Button
            Button(action: {
                viewModel.playCurrentNote()
            }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 80))
            }
            .padding(40)
            .background(Color.accentColor.opacity(0.2))
            .clipShape(Circle())
            .disabled(viewModel.selectedNote != nil) // Disable after answering

            Spacer()

            // Answer Choices
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(viewModel.answerChoices) { note in
                    Button(action: {
                        if viewModel.selectedNote == nil {
                            viewModel.submitAnswer(for: note)
                        }
                    }) {
                        Text(note.name)
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(buttonColor(for: note))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }

            // Feedback and Next Button
            if let feedback = viewModel.feedbackMessage {
                Text(feedback)
                    .font(.headline)
                    .padding()
                
                Button("Next", action: viewModel.nextRound)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var gameOverView: some View {
        VStack(spacing: 20) {
            Text("Game Over!")
                .font(.largeTitle.bold())
            
            Text("Your final score is")
                .font(.title2)
            
            Text("\(viewModel.score) / 10")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.accentColor)
            
            Button("Play Again") {
                viewModel.isGameActive = false // Go back to the start screen
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private func buttonColor(for note: TuningNote) -> Color {
        guard let selected = viewModel.selectedNote, let correct = viewModel.currentQuestion else {
            return .accentColor
        }
        
        if selected.id == note.id {
            return selected.id == correct.id ? .green : .red
        }
        
        if note.id == correct.id && selected.id != correct.id {
            return .green
        }
        
        return .gray.opacity(0.5)
    }
}
