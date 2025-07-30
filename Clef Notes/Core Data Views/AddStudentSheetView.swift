import SwiftUI
import CoreData
import PhotosUI

struct AddStudentSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @Binding var isPresented: Bool
    @Binding var selectedStudent: StudentCD?
    
    @State private var newName = ""
    @State private var newInstrument: Instrument? = nil
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedAvatarData: Data?
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section("Avatar") {
                        HStack {
                            Spacer()
                            VStack {
                                if let avatarData = selectedAvatarData, let uiImage = UIImage(data: avatarData) {
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
                                PhotosPicker("Choose Avatar", selection: $selectedAvatarItem, matching: .images)
                                    .buttonStyle(.bordered)
                            }
                            Spacer()
                        }
                        .padding(.vertical)
                    }
                    
                    Section("Student Details") {
                        TextField("Name", text: $newName)
                        Picker("Instrument", selection: $newInstrument) {
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
                .addDoneButtonToKeyboard()

                SaveButtonView(title: "Add Student", action: {
                    addStudent()
                    isPresented = false
                }, isDisabled: newName.trimmingCharacters(in: .whitespaces).isEmpty || newInstrument == nil)
            }
            .navigationTitle("New Student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: selectedAvatarItem) {
                Task {
                    if let data = try? await selectedAvatarItem?.loadTransferable(type: Data.self) {
                        selectedAvatarData = data
                    }
                }
            }
        }
    }
    
    private func addStudent() {
        let newStudent = StudentCD(context: viewContext)
        newStudent.id = UUID()
        newStudent.name = newName
        newStudent.instrumentType = newInstrument
        newStudent.avatar = selectedAvatarData
        do {
            try viewContext.save()
            selectedStudent = newStudent
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}
