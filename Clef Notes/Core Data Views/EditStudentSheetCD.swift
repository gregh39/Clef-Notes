//
//  EditStudentSheetCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/19/25.
//


import SwiftUI
import CoreData

struct EditStudentSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var student: StudentCD
    
    // State variables to hold the edited values
    @State private var name: String = ""
    @State private var instrument: Instrument? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Student Details") {
                    TextField("Name", text: $name)
                    Picker("Instrument", selection: $instrument) {
                        Text("Select an Instrument").tag(Optional<Instrument>.none)
                        ForEach(instrumentSections) { section in
                            Section(header: Text(section.name)) {
                                ForEach(section.instruments) { instrument in
                                    Text(instrument.rawValue).tag(Optional(instrument))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || instrument == nil)
                }
            }
            .onAppear {
                // Pre-fill the form with the student's current data
                name = student.name ?? ""
                instrument = student.instrumentType
            }
        }
    }
    
    private func saveChanges() {
        student.name = name
        student.instrumentType = instrument
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save student changes: \(error)")
        }
    }
}