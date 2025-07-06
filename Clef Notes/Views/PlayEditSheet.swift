// PlayEditSheet.swift
// Sheet for editing a Play (date, play type, count)

import SwiftUI
import SwiftData

struct PlayEditSheet: View {
    // 1. Get the dismiss action from the environment.
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    // The 'play' object is now the only property passed in.
    @State var play: Play
    var onSave: (() -> Void)? = nil

    @State private var newDate: Date
    @State private var newPlayType: PlayType?
    @State private var newCount: Int

    // 2. Update the initializer.
    init(play: Play, onSave: (() -> Void)? = nil) {
        _play = State(initialValue: play)
        self.onSave = onSave
        _newDate = State(initialValue: play.session?.day ?? Date())
        _newPlayType = State(initialValue: play.playType)
        _newCount = State(initialValue: play.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                // ... your form sections remain the same
                Section("Date") {
                    DatePicker("Date", selection: $newDate, displayedComponents: .date)
                }
                Section("Play Type") {
                    Picker("Play Type", selection: $newPlayType) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Optional(type))
                        }
                    }
                }
                Section("Count") {
                    Stepper(value: $newCount, in: 1...100) {
                        Text("Count: \(newCount)")
                    }
                }
            }
            .navigationTitle("Edit Play")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // 3. Call dismiss() instead of modifying a binding.
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        play.count = newCount
                        play.playType = newPlayType
                        play.session?.day = newDate
                        try? context.save()
                        onSave?()
                        // 4. Call dismiss() here as well.
                        dismiss()
                    }
                }
            }
        }
    }
}
