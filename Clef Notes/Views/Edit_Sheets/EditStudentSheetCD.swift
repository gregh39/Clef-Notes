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
    
    @State private var isSuzukiStudent: Bool = false
    @State private var selectedSuzukiBook: SuzukiBook? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
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
                        Toggle("Suzuki Student", isOn: $isSuzukiStudent)
                        if isSuzukiStudent {
                            Picker("Suzuki Book", selection: $selectedSuzukiBook) {
                                Text("Select a Book").tag(Optional<SuzukiBook>.none)
                                ForEach(SuzukiBook.allCases) { book in
                                    Text(book.rawValue).tag(Optional(book))
                                }
                            }
                        }
                    }
                }
                .addDoneButtonToKeyboard()

                SaveButtonView(title: "Save Changes", action: saveChanges, isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty || instrument == nil)
            }
            .navigationTitle("Edit Student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                name = student.name ?? ""
                instrument = student.instrumentType
                avatarData = student.avatar
                
                isSuzukiStudent = student.suzukiStudent?.boolValue ?? false
                selectedSuzukiBook = student.suzukiBook
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
        
        student.suzukiStudent = NSNumber(value: isSuzukiStudent)
        student.suzukiBookRaw = isSuzukiStudent ? selectedSuzukiBook?.rawValue : nil
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save student changes: \(error)")
        }
    }
}
