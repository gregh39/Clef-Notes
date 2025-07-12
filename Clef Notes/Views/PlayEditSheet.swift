// PlayEditSheet.swift
// Sheet for editing a Play (date, play type, count)

import SwiftUI
import SwiftData

struct PlayEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    // --- MODIFIED: Use @Bindable for direct binding ---
    @Bindable var play: Play
    var onSave: (() -> Void)? = nil

    // The initializer and local @State variables are no longer needed.

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    // --- MODIFIED: Bind directly to the session's date ---
                    DatePicker("Date", selection: Binding(
                        get: { play.session?.day ?? Date() },
                        set: { play.session?.day = $0 }
                    ), displayedComponents: .date)
                }
                Section("Play Type") {
                    // --- MODIFIED: Bind directly to the play's type ---
                    Picker("Play Type", selection: $play.playType) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Optional(type))
                        }
                    }
                }
                Section("Count") {
                    // --- MODIFIED: Bind directly to the play's count ---
                    Stepper(value: $play.count, in: 1...100) {
                        Text("Count: \(play.count)")
                    }
                }
            }
            .navigationTitle("Edit Play")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // All changes are already saved to the 'play' object.
                        try? context.save()
                        onSave?()
                        dismiss()
                    }
                }
            }
        }
    }
}
