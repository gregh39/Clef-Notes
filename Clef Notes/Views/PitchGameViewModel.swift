import Foundation
import AVFoundation
import SwiftUI
import TelemetryDeck

@MainActor
@Observable
class PitchGameViewModel {
    var audioManager: AudioManager
    
    // Game State
    var answerChoices: [TuningNote] = []
    var currentQuestion: TuningNote?
    var score = 0
    var questionsAsked = 0
    var isGameOver = false
    var isGameActive = false // Add this new state

    // UI State
    var selectedNote: TuningNote?
    var feedbackMessage: String?
    
    private let allNotes = TunerViewModel.availableNotes(for: 4) // Middle octave

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }

    func startGame() {
        score = 0
        questionsAsked = 0
        isGameOver = false
        isGameActive = true // Activate the game
        TelemetryDeck.signal("pitch_game_started")
        nextRound()
    }

    func nextRound() {
        guard questionsAsked < 10 else {
            isGameOver = true
            TelemetryDeck.signal("pitch_game_ended", parameters: ["score": "\(score)", "questions": "\(questionsAsked)"])
            feedbackMessage = "Game Over! Your final score is \(score)/10."
            return
        }
        
        selectedNote = nil
        feedbackMessage = nil
        
        // Pick a random note for the question
        currentQuestion = allNotes.randomElement()
        
        // Generate answer choices
        var choices = Set([currentQuestion!])
        while choices.count < 4 {
            if let randomNote = allNotes.randomElement() {
                choices.insert(randomNote)
            }
        }
        answerChoices = Array(choices).shuffled()
        
        questionsAsked += 1
        
        // Play the note shortly after the round starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.playCurrentNote()
        }
    }

    func playCurrentNote() {
        guard let note = currentQuestion, !isGameOver else { return }
        audioManager.playSineWave(frequency: note.frequency, duration: 0.5)
    }

    func submitAnswer(for note: TuningNote) {
        selectedNote = note
        if note.id == currentQuestion?.id {
            feedbackMessage = "Correct!"
            score += 1
        } else {
            feedbackMessage = "Not quite! The correct answer was \(currentQuestion?.name ?? "")."
        }
    }
}

