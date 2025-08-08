import SwiftUI
import CoreData

struct PlayEditSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var play: PlayCD

    // Local state for editing
    @State private var date: Date = .now
    @State private var playType: PlayType?
    @State private var count: Int = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Play Type") {
                    Picker("Play Type", selection: $playType) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Optional(type))
                        }
                    }
                }
                Section("Count") {
                    Stepper(value: $count, in: 1...100) {
                        Text("Count: \(count)")
                    }
                }
            }
            .navigationTitle("Edit Play")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save local state back to the object
                        play.session?.day = date
                        play.playType = playType
                        play.count = Int64(count)
                        
                        try? viewContext.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Populate state when the view appears
                date = play.session?.day ?? .now
                playType = play.playType
                count = Int(play.count)
            }
        }
    }
}
