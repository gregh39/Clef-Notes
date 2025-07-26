// Clef Notes/Views/ContentView.swift

import SwiftUI
import CoreData
import PhotosUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var usageManager: UsageManager

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StudentCD.name, ascending: true)],
        animation: .default)
    private var students: FetchedResults<StudentCD>
    
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingPaywall = false

    @State private var selectedStudent: StudentCD?
    @State private var showingAddSheet = false
    
    // State variables to control the global tools sheets
    @State private var showingSettingsSheet = false
    @State private var showingMetronome = false
    @State private var showingTuner = false
    
    @State private var offsetsToDelete: IndexSet?
    
    @State private var newName = ""
    @State private var newInstrument: Instrument? = nil
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedAvatarData: Data?
    @AppStorage("shareAccepted") private var shareAccepted: Bool = false

    var body: some View {
        NavigationSplitView {
            studentListView
        } detail: {
            if let student = selectedStudent {
                StudentDetailNavigationView(student: student)
            } else {
                Text("Select a student")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
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
                                  newInstrument == nil)
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
        .alert("Welcome!", isPresented: Binding(
            get: { shareAccepted },
            set: { if !$0 { shareAccepted = false } }
        )) {
            Button("OK") { shareAccepted = false }
        } message: {
            Text("You joined a shared student or content! The share was accepted.")
        }
        .withGlobalTools(
            showingSettings: $showingSettingsSheet,
            showingMetronome: $showingMetronome,
            showingTuner: $showingTuner
        )
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    private var studentListView: some View {
        List(selection: $selectedStudent) {
            ForEach(students) { student in
                Section {
                    ZStack {
                        StudentCellView(student: student)
                        NavigationLink(value: student) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                }
            }
            .onDelete(perform: { offsets in
                self.offsetsToDelete = offsets
            })
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Students")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button { showingMetronome = true } label: {
                        Label("Metronome", systemImage: "metronome")
                    }
                    Button { showingTuner = true } label: {
                        Label("Tuner", systemImage: "tuningfork")
                    }
                    Divider()
                    Button { showingSettingsSheet = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Label("Tools", systemImage: "line.3.horizontal")
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                EditButton()
                Button {
                    if subscriptionManager.isAllowedToCreateStudent() {
                        showingAddSheet = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Label("Add Student", systemImage: "plus")
                }
            }
        }
        .alert("Delete Student?",
               isPresented: .constant(offsetsToDelete != nil),
               actions: {
                    Button("Delete", role: .destructive) {
                        if let offsets = offsetsToDelete {
                            deleteStudents(offsets: offsets)
                        }
                        offsetsToDelete = nil
                    }
                    Button("Cancel", role: .cancel) {
                        offsetsToDelete = nil
                    }
               },
               message: {
                    Text("This will permanently delete the student and all of their songs, sessions, and plays. This action cannot be undone.")
               })
    }

    private func addStudent() {
        let newStudent = StudentCD(context: viewContext)
        newStudent.id = UUID()
        newStudent.name = newName
        newStudent.instrumentType = newInstrument
        newStudent.avatar = selectedAvatarData
        usageManager.incrementStudentCreations()
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func deleteStudents(offsets: IndexSet) {
        withAnimation {
            offsets.map { students[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func clearForm() {
        newName = ""
        newInstrument = nil
        selectedAvatarItem = nil
        selectedAvatarData = nil
    }
}

private struct StudentCellView: View {
    @ObservedObject var student: StudentCD
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var currentStreak: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(student.sessionsArray.map { calendar.startOfDay(for: $0.day ?? .distantPast) })
        let sortedDates = uniqueDays.sorted(by: >)

        guard !sortedDates.isEmpty else { return 0 }

        var streak = 0
        var dateToMatch = calendar.startOfDay(for: .now)

        if !sortedDates.contains(dateToMatch) {
            dateToMatch = calendar.date(byAdding: .day, value: -1, to: dateToMatch)!
            if !sortedDates.contains(dateToMatch) {
                return 0
            }
        }

        for practiceDate in sortedDates {
            if practiceDate == dateToMatch {
                streak += 1
                dateToMatch = calendar.date(byAdding: .day, value: -1, to: dateToMatch)!
            } else {
                break
            }
        }
        return streak
    }

    var body: some View {
        HStack(spacing: 8) {
            if let avatarData = student.avatar, let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(student.name ?? "Unknown Student")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    if student.isShared {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.secondary)
                    }
                }
                Text(student.instrument ?? "No Instrument")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider().padding(.vertical, 2)
                
                HStack(spacing: 16) {
                    HStack{
                        Image(systemName: "flame.fill")
                        Text("\(currentStreak) Day Streak")
                    }
                    .foregroundColor(currentStreak > 0 ? .orange : .secondary)
                    Spacer()
                    if let lastSessionDate = student.sessionsArray.first?.day {
                        HStack{
                            Image(systemName: "clock.arrow.circlepath")
                            Text(Self.dateFormatter.string(from: lastSessionDate))
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
