// Clef Notes/Core Data Views/EditStudentSheetCD.swift

import SwiftUI
import CoreData
import PhotosUI

struct EditStudentSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var student: StudentCD
    
    @State private var name: String = ""
    @State private var instrument: Instrument? = nil
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var avatarData: Data?
    
    var body: some View {
        NavigationStack {
            Form {
                // --- THIS IS THE FIX ---
                Section("Avatar") {
                    HStack {
                        Spacer()
                        VStack {
                            if let data = avatarData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.gray)
                            }
                            PhotosPicker("Change Avatar", selection: $selectedAvatarItem, matching: .images)
                                .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }
                
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
                name = student.name ?? ""
                instrument = student.instrumentType
                avatarData = student.avatar
            }
            .onChange(of: selectedAvatarItem) {
                Task {
                    if let data = try? await selectedAvatarItem?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        student.name = name
        student.instrumentType = instrument
        student.avatar = avatarData
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save student changes: \(error)")
        }
    }
}
