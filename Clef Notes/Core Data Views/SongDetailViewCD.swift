// Clef Notes/Core Data Views/SongDetailViewCD.swift

import SwiftUI
import CoreData
import AVKit
import PDFKit
import UniformTypeIdentifiers
import CoreText

// A wrapper to display different media types in one list.
enum DisplayableMedia: Identifiable, Hashable {
    case mediaReference(MediaReferenceCD)
    case audioRecording(AudioRecordingCD)
    
    var id: NSManagedObjectID {
        switch self {
        case .mediaReference(let ref):
            return ref.objectID
        case .audioRecording(let rec):
            return rec.objectID
        }
    }

    // Helper property to get a consistent type name for grouping
    var mediaType: String {
        switch self {
        case .mediaReference(let ref):
            return ref.type?.rawValue ?? "Media"
        case .audioRecording:
            return MediaType.audioRecording.rawValue
        }
    }
}

// A new struct to hold grouped notes
private struct NoteGroup: Identifiable {
    var id: Date { date }
    let date: Date
    let notes: [NoteCD]
}

// MARK: - New Components for Custom Tab Bar
/// Defines the sections for the custom bottom navigation bar.
private enum SongDetailSection: String, CaseIterable, Identifiable {
    case song = "Song"
    case plays = "Plays"
    case media = "Media"
    case notes = "Notes"

    var id: String { self.rawValue }

    /// Provides the SF Symbol name for each section.
    var systemImageName: String {
        switch self {
        case .song:
            return "music.note"
        case .plays:
            return "music.note.list"
        case .media:
            return "folder"
        case .notes:
            return "note.text"
        }
    }
}

/// The custom bottom navigation bar view.
private struct SongDetailBottomNavBar: View {
    @Binding var selectedSection: SongDetailSection
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            ForEach(SongDetailSection.allCases) { section in
                Button(action: {
                    // Switch to the selected section
                    selectedSection = section
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: section.systemImageName)
                            .font(.system(size: 22))
                        Text(section.rawValue)
                            .font(.system(size: 10)) // Matched to original
                    }
                    // Highlight the selected section
                    .foregroundColor(selectedSection == section ? .accentColor : .gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 5) // Matched to original
        //.padding(.bottom, 35) // Matched to original
        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
    }
}

private struct SongDetailNavButtons: View {
    @Binding var selectedSection: SongDetailSection
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.horizontal){
            HStack() {
                ForEach(SongDetailSection.allCases) { section in
                    if #available(iOS 26.0, *) {
                        Button {
                            selectedSection = section
                        } label: {
                            Text(section.rawValue)
                                .font(.callout.weight(.semibold))
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .glassEffect(selectedSection == section ?  .regular.tint(.accentColor).interactive() : .clear.interactive())
                    }
                }
            }
            .padding()
        }
    }
}


// MARK: - Main Detail View
struct SongDetailViewCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    @ObservedObject var song: SongCD

    // State for the custom navigation bar
    @State private var selectedSection: SongDetailSection = .song
    

    @State private var showingEditSheet = false
    @State private var showingAddMediaSheet = false
    @StateObject private var audioPlayerManager: AudioPlayerManager
    
    @State private var noteToEdit: NoteCD?
    @State private var hundredsChartPDF: IdentifiableURL?
    
    // Rename state
    @State private var mediaReferenceToRename: MediaReferenceCD?
    @State private var audioRecordingToRename: AudioRecordingCD?
    @State private var newTitleText: String = ""

    init(song: SongCD, audioManager: AudioManager) {
        self.song = song
        _audioPlayerManager = StateObject(wrappedValue: AudioPlayerManager(audioManager: audioManager))
    }

    private var allMediaItems: [DisplayableMedia] {
        let references = song.mediaArray.map { DisplayableMedia.mediaReference($0) }
        let recordings = song.recordingsArray.map { DisplayableMedia.audioRecording($0) }
        return references + recordings
    }

    private var groupedNotes: [NoteGroup] {
        let grouped = Dictionary(grouping: song.notesArray) { note -> Date in
            let dateToUse = note.date ?? note.session?.day ?? .distantPast
            return Calendar.current.startOfDay(for: dateToUse)
        }
        
        return grouped.map { NoteGroup(date: $0, notes: $1) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            if #available(iOS 26.0, *) {
                // Main content area that switches based on the selected section
                switch selectedSection {
                case .song:
                    songTab
                case .plays:
                    playsTab
                case .media:
                    mediaTab
                case .notes:
                    notesTab
                }
            } else {
                switch selectedSection {
                case .song:
                    songTab
                        .navigationTitle(song.title ?? "Song")
                case .plays:
                    playsTab
                        .navigationTitle(song.title ?? "Song")
                case .media:
                    mediaTab
                        .navigationTitle(song.title ?? "Song")
                case .notes:
                    notesTab
                        .navigationTitle(song.title ?? "Song")
                }
                
                SongDetailBottomNavBar(selectedSection: $selectedSection)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingAddMediaSheet = true
                } label: {
                    Label("Add Media", systemImage: "folder.badge.plus")
                }
                
                Button {
                    showingEditSheet = true
                }
                label: {
                    Label("Edit Song", systemImage: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSongSheetCD(song: song)
        }
        .sheet(isPresented: $showingAddMediaSheet) {
            AddMediaSheetCD(song: song)
        }
        .sheet(item: $noteToEdit) { note in
            AddNoteSheetCD(note: note)
        }
        .sheet(item: $hundredsChartPDF) { identifiableURL in
            ActivityViewController(activityItems: [identifiableURL.url])
        }
        .safeAreaInset(edge: .top) {
            if #available(iOS 26.0, *) {
                SongDetailNavButtons(selectedSection: $selectedSection)
            }
        }
        // Rename sheets
        .sheet(item: $mediaReferenceToRename, onDismiss: { newTitleText = "" }) { media in
            RenameTitleSheet(
                title: media.title ?? "",
                onSave: { newTitle in
                    media.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    try? viewContext.save()
                }
            )
        }
        .sheet(item: $audioRecordingToRename, onDismiss: { newTitleText = "" }) { rec in
            RenameTitleSheet(
                title: rec.title ?? "",
                onSave: { newTitle in
                    rec.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    try? viewContext.save()
                }
            )
        }
    }

    private var songTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Song Image and Title Section
                VStack(spacing: 12) {
                    if let imageData = song.image, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.tertiary)
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                            }
                    }
                    
                    VStack(spacing: 4) {
                        Text(song.title ?? "Untitled Song")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        
                        if let composer = song.composer, !composer.isEmpty {
                            Text("by \(composer)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack{
                            if let pieceType = song.pieceType {
                                Text(pieceType.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.tertiary.opacity(0.5))
                                    .clipShape(Capsule())
                            }
                            
                            if song.archived{
                                Text("Archived")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.red.opacity(0.5))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if let suzukiBook = song.suzukiBook {
                            Text(suzukiBook.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                        
                        if let collection = song.collection?.name {
                            Text(collection)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }

                    }
                }
                
                // Practice Goal Progress
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Practice Goal")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button {
                            generateHundredsChart()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "grid.circle")
                                Text("Hundreds Chart")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    let progressValue = song.goalPlays > 0 ? Double(song.totalGoalPlayCount) / Double(song.goalPlays) : 0.0
                    let isGoalComplete = song.totalGoalPlayCount >= song.goalPlays && song.goalPlays > 0
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(song.totalGoalPlayCount) / \(song.goalPlays) plays")
                                .font(.subheadline.bold())
                            Spacer()
                            if isGoalComplete {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                            } else {
                                Text("\(Int(progressValue * 100))%")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        ProgressView(value: min(progressValue, 1.0))
                            .tint(isGoalComplete ? .green : .accentColor)
                        
                        if song.goalPlays > 0 && !isGoalComplete {
                            Text("\(Int(song.goalPlays) - song.totalGoalPlayCount) more practices to reach goal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if isGoalComplete {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Goal completed! 🎉")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                                
                                if let completionDate = getGoalCompletionDate() {
                                    Text("Completed on \(completionDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else if song.goalPlays == 0 {
                            Text("No practice goal set")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Statistics Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    // Total Plays
                    StatCardView(
                        title: "Total Plays",
                        value: "\(song.totalPlayCount)",
                        icon: "music.note.list",
                        color: .blue
                    )
                    
                    // Play Types Breakdown
                    let learningPlays = song.playsArray.filter { $0.playType == .learning }.reduce(0) { $0 + Int($1.count) }
                    let reviewPlays = song.playsArray.filter { $0.playType == .review }.reduce(0) { $0 + Int($1.count) }
                    
                    StatCardView(
                        title: "Practice Types",
                        value: "L:\(learningPlays) P:\(song.totalGoalPlayCount) R:\(reviewPlays)",
                        icon: "chart.pie",
                        color: .orange
                    )
                    
                    // Media Count
                    StatCardView(
                        title: "Media Files",
                        value: "\(allMediaItems.count)",
                        icon: "folder",
                        color: .purple
                    )
                    
                    // Notes Count
                    StatCardView(
                        title: "Notes",
                        value: "\(song.notesArray.count)",
                        icon: "note.text",
                        color: .green
                    )
                }
                
                // Dates Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Practice History")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 8) {
                        if let firstPlayDate = song.playsArray.compactMap({ $0.session?.day }).min() {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text("First practiced:")
                                Spacer()
                                Text(firstPlayDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let lastPlayDate = song.lastPlayedDate {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                                    .frame(width: 20)
                                Text("Last practiced:")
                                Spacer()
                                Text(lastPlayDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if song.playsArray.count > 1,
                           let firstDate = song.playsArray.compactMap({ $0.session?.day }).min(),
                           let lastDate = song.playsArray.compactMap({ $0.session?.day }).max() {
                            let daysBetween = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
                            HStack {
                                Image(systemName: "calendar.day.timeline.left")
                                    .foregroundColor(.purple)
                                    .frame(width: 20)
                                Text("Days practiced:")
                                Spacer()
                                Text("\(daysBetween + 1) days")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Practice sessions count
                        let sessionCount = Set(song.playsArray.compactMap { $0.session }).count
                        if sessionCount > 0 {
                            HStack {
                                Image(systemName: "list.bullet.clipboard")
                                    .foregroundColor(.green)
                                    .frame(width: 20)
                                Text("Practice sessions:")
                                Spacer()
                                Text("\(sessionCount)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Recent Activity
                if !song.playsArray.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        let recentPlays = Array(song.playsArray.prefix(3))
                        ForEach(recentPlays) { play in
                            HStack {
                                Image(systemName: iconForPlayType(play.playType))
                                    .foregroundColor(colorForPlayType(play.playType))
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(play.playType?.rawValue ?? "Practice")
                                        .font(.subheadline.bold())
                                    if let date = play.session?.day {
                                        Text(date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(play.count) plays")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.tertiary.opacity(0.5))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle(song.title ?? "Song")
    }
    
    private func iconForPlayType(_ playType: PlayType?) -> String {
        switch playType {
        case .learning:
            return "book"
        case .practice:
            return "figure.walk"
        case .review:
            return "arrow.clockwise"
        case .none:
            return "music.note"
        }
    }
    
    private func colorForPlayType(_ playType: PlayType?) -> Color {
        switch playType {
        case .learning:
            return .blue
        case .practice:
            return .orange
        case .review:
            return .green
        case .none:
            return .gray
        }
    }
    
    private func getGoalCompletionDate() -> Date? {
        // Get all practice plays sorted by date
        let practicePlaysSorted = song.playsArray
            .filter { $0.playType == .practice }
            .sorted { 
                let date1 = $0.session?.day ?? .distantPast
                let date2 = $1.session?.day ?? .distantPast
                return date1 < date2
            }
        
        var cumulativeCount = 0
        for play in practicePlaysSorted {
            cumulativeCount += Int(play.count)
            if cumulativeCount >= song.goalPlays {
                return play.session?.day
            }
        }
        
        return nil
    }

    private var playsTab: some View {
        PlaysListViewCD(song: song, context: viewContext)
    }

    private var mediaTab: some View {
        let groupedMedia = Dictionary(grouping: allMediaItems, by: { $0.mediaType })
        let sortedKeys = groupedMedia.keys.sorted()

        return List {
            if allMediaItems.isEmpty {
                Text("No media has been added to this song.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(sortedKeys, id: \.self) { key in
                    Section(header: Text(key)) {
                        ForEach(groupedMedia[key] ?? []) { item in
                            switch item {
                            case .mediaReference(let media):
                                MediaCellCD(media: media, audioPlayerManager: audioPlayerManager)
                                    .padding(.vertical, 4)
                                    // Leading swipe (right) for Rename
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            mediaReferenceToRename = media
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                                    // Trailing swipe (left) for Delete
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            if let index = (groupedMedia[key] ?? []).firstIndex(of: .mediaReference(media)) {
                                                deleteMedia(at: IndexSet(integer: index), from: groupedMedia[key] ?? [])
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                                .foregroundStyle(Color.red)

                                        }
                                        .tint(.red)

                                    }
                            case .audioRecording(let recording):
                                AudioPlaybackCellCD(
                                    title: recording.title ?? "Recording",
                                    subtitle: (recording.dateRecorded ?? .now).formatted(date: .abbreviated, time: .shortened),
                                    data: recording.data,
                                    duration: recording.duration,
                                    id: recording.objectID,
                                    audioPlayerManager: audioPlayerManager
                                )
                                .padding(.vertical, 4)
                                // Leading swipe (right) for Rename
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        audioRecordingToRename = recording
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                // Trailing swipe (left) for Delete
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let index = (groupedMedia[key] ?? []).firstIndex(of: .audioRecording(recording)) {
                                            deleteMedia(at: IndexSet(integer: index), from: groupedMedia[key] ?? [])
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            deleteMedia(at: indexSet, from: groupedMedia[key] ?? [])
                        }
                    }
                }

            }
        }
        .navigationTitle(song.title ?? "Song")

    }
    
    private var notesTab: some View {
        List {
            ForEach(groupedNotes) { group in
                Section(header: Text(group.date, style: .date)) {
                    ForEach(group.notes) { note in
                        Button(action: {
                            noteToEdit = note
                        }) {
                            NoteCellCD(note: note)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        deleteNote(at: indexSet, from: group.notes)
                    }
                }
            }
        }
        .navigationTitle(song.title ?? "Song")
        .navigationBarTitleDisplayMode(.large)
        

    }
    
    private func deleteMedia(at offsets: IndexSet, from mediaGroup: [DisplayableMedia]) {
        for index in offsets {
            let itemToDelete = mediaGroup[index]
            switch itemToDelete {
            case .mediaReference(let ref):
                viewContext.delete(ref)
            case .audioRecording(let rec):
                viewContext.delete(rec)
            }
        }
        try? viewContext.save()
    }
    
    private func deleteNote(at offsets: IndexSet, from notes: [NoteCD]) {
        for index in offsets {
            let noteToDelete = notes[index]
            viewContext.delete(noteToDelete)
        }
        try? viewContext.save()
    }
    
    private func generateHundredsChart() {
        Task {
            let pdfURL = await createHundredsChartPDF()
            await MainActor.run {
                if let pdfURL = pdfURL {
                    self.hundredsChartPDF = IdentifiableURL(url: pdfURL)
                } else {
                    print("Failed to generate Hundreds Chart PDF")
                }
            }
        }
    }
    
    private func createHundredsChartPDF() async -> URL? {
        // Create a temporary file URL for the PDF
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pdfURL = documentsPath.appendingPathComponent("HundredsChart_\(UUID().uuidString).pdf")
        
        // 8.5" x 11" at 72 DPI
        let pageWidth: CGFloat = 612  // 8.5 * 72
        let pageHeight: CGFloat = 792 // 11 * 72
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        // Create PDF context
        guard let pdfContext = CGContext(pdfURL as CFURL, mediaBox: &pageRect, nil) else {
            return nil
        }
        
        pdfContext.beginPDFPage(nil)
        
        // Draw the content
        let margin: CGFloat = 36 // 0.5 inch margin
        let contentWidth = pageWidth - (2 * margin)
        _ = pageHeight - (2 * margin)
        
        // Header area (student name and song title)
        let headerHeight: CGFloat = 80
        let headerRect = CGRect(x: margin, y: pageHeight - margin - headerHeight, width: contentWidth, height: headerHeight)
        
        drawHeader(in: pdfContext, rect: headerRect)
        
        // Grid area
        let gridTop = headerRect.minY - 10 // 20 points spacing
        let gridHeight = gridTop - margin
        let gridRect = CGRect(x: margin, y: margin, width: contentWidth, height: gridHeight)
        
        drawHundredsGrid(in: pdfContext, rect: gridRect)
        
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        return pdfURL
    }
    
    private func drawHeader(in context: CGContext, rect: CGRect) {
        let studentName = song.student?.name ?? "Student Name"
        let songTitle = song.title ?? "Song Title"
        
        // Save the graphics state
        context.saveGState()
        
        // Set up fonts
        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 24, nil)
        let nameFont = CTFontCreateWithName("Helvetica" as CFString, 18, nil)
        
        // Draw song title
        let titleString = NSMutableAttributedString(string: songTitle)
        titleString.addAttribute(.font, value: titleFont, range: NSRange(location: 0, length: songTitle.count))
        titleString.addAttribute(.foregroundColor, value: UIColor.black, range: NSRange(location: 0, length: songTitle.count))
        
        let titleFrame = CTFramesetterCreateFrame(
            CTFramesetterCreateWithAttributedString(titleString),
            CFRange(location: 0, length: 0),
            CGPath(rect: CGRect(x: rect.minX, y: rect.maxY - 30, width: rect.width, height: 30), transform: nil),
            nil
        )
        CTFrameDraw(titleFrame, context)
        
        // Draw student name
        let nameText = "\(studentName)"
        let nameString = NSMutableAttributedString(string: nameText)
        nameString.addAttribute(.font, value: nameFont, range: NSRange(location: 0, length: nameText.count))
        nameString.addAttribute(.foregroundColor, value: UIColor.black, range: NSRange(location: 0, length: nameText.count))
        
        let nameFrame = CTFramesetterCreateFrame(
            CTFramesetterCreateWithAttributedString(nameString),
            CFRange(location: 0, length: 0),
            CGPath(rect: CGRect(x: rect.minX, y: rect.maxY - 60, width: rect.width, height: 25), transform: nil),
            nil
        )
        CTFrameDraw(nameFrame, context)
        
        // Restore the graphics state
        context.restoreGState()
    }
    
    private func drawHundredsGrid(in context: CGContext, rect: CGRect) {
        let gridSize: CGFloat = 10 // 10x10 grid
        let spacing: CGFloat = 8 // Space between each cell
        
        // Determine how many cells to draw based on the song's goal
        let goalCells = max(0, min(Int(song.goalPlays), 100))
        
        var drawnCount = 0
        
        // Calculate cell dimensions with proper spacing
        let totalSpacingWidth = spacing * (gridSize + 1) // spacing around and between cells
        let totalSpacingHeight = spacing * (gridSize + 1)
        
        let cellWidth = (rect.width - totalSpacingWidth) / gridSize
        let cellHeight = (rect.height - totalSpacingHeight) / gridSize
        
        // Get the song image or create a default one
        let songImage = getSongUIImage()
        
        // Draw 100 images in a 10x10 grid
        for row in 0..<Int(gridSize) {
            for col in 0..<Int(gridSize) {
                let cellRect = CGRect(
                    x: rect.minX + spacing + (CGFloat(col) * (cellWidth + spacing)),
                    y: rect.minY + spacing + (CGFloat(row) * (cellHeight + spacing)),
                    width: cellWidth,
                    height: cellHeight
                )
                
                // Only draw up to the goal number of cells
                guard drawnCount < goalCells else { continue }

                // Draw the image with a small internal padding
                let imagePadding: CGFloat = 1
                let imageRect = cellRect.insetBy(dx: imagePadding, dy: imagePadding)

                if let cgImage = songImage.cgImage {
                    context.draw(cgImage, in: imageRect)
                }

                drawnCount += 1
            }
        }
    }
    
    private func getSongUIImage() -> UIImage {
        // Try to get the song's image
        if let imageData = song.image,
           let image = UIImage(data: imageData) {
            return image
        }
        
        // Create a default image with music note
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Fill with light background
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw music note icon
            let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .medium)
            if let musicNote = UIImage(systemName: "music.note", withConfiguration: config) {
                UIColor.gray.setFill()
                let imageRect = CGRect(
                    x: (size.width - 60) / 2,
                    y: (size.height - 60) / 2,
                    width: 60,
                    height: 60
                )
                musicNote.draw(in: imageRect)
            }
        }
    }
}

// MARK: - StatCardView for Song Summary
private struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline.bold())
                .multilineTextAlignment(.center)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Identifiable URL Wrapper for Sheet Presentation
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - ActivityViewController for Share Sheet
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Rename Sheet
private struct RenameTitleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var titleText: String
    let onSave: (String) -> Void
    
    init(title: String, onSave: @escaping (String) -> Void) {
        _titleText = State(initialValue: title)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $titleText)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Rename")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed.isEmpty ? "Recording" : trimmed)
                        dismiss()
                    }
                }
            }
        }
    }
}

