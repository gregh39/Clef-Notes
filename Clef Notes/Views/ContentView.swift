//
//  ContentView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Student.name) private var students: [Student]

    @State private var selectedStudent: Student?
    @State private var showingAddSheet = false
    
    // 1. State to control the settings sheet presentation
    @State private var showingSettingsSheet = false
    
    @State private var newName = ""
    @State private var newInstrument = ""

    var body: some View {
        NavigationSplitView {
            List(students, id: \.id, selection: $selectedStudent) { student in
                NavigationLink(value: student) {
                    VStack(alignment: .leading) {
                        Text(student.name)
                            .font(.headline)
                        Text(student.instrument)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Students")
            .toolbar {
                // 2. Add a new ToolbarItem for the settings button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Student", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let student = selectedStudent {
                StudentDetailView(student: student, context: modelContext)
            } else {
                Text("Select a student")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                Form {
                    TextField("Name", text: $newName)
                    TextField("Instrument", text: $newInstrument)
                }
                .navigationTitle("New Student")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddSheet = false
                            clearForm()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            addStudent()
                            showingAddSheet = false
                            clearForm()
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  newInstrument.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        // 3. Add the new sheet modifier for the settings menu
        .sheet(isPresented: $showingSettingsSheet) {
            NavigationStack {
                SettingsView() // This view contains your theme picker
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingSettingsSheet = false
                            }
                        }
                    }
            }
        }
    }

    private func addStudent() {
        let student = Student(name: newName, instrument: newInstrument)
        modelContext.insert(student)
    }

    private func clearForm() {
        newName = ""
        newInstrument = ""
    }
}
#Preview {
    ContentView()
        .modelContainer(for: Student.self, inMemory: true)
}
