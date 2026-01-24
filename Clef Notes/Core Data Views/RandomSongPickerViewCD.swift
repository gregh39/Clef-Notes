import SwiftUI
import CoreData

struct RandomSongPickerViewCD: View {
    /// Return the studentID of the first song (if available)
    private var studentID: UUID? {
        songs.first?.studentID
    }
    
    /// Returns a UserDefaults key based on studentID and base key string.
    /// If studentID is nil, returns base key as-is.
    private static func key(for studentID: UUID?, base: String) -> String {
        guard let id = studentID else { return base }
        return "\(base).\(id.uuidString)"
    }
    
    private static let baseStatusesKey = "RandomSongPickerViewCD.selectedStatuses"
    private static let baseTypesKey = "RandomSongPickerViewCD.selectedTypes"
    private static let baseBooksKey = "RandomSongPickerViewCD.selectedBooks"
    
    let songs: [SongCD]
    @State private var selectedSong: SongCD? = nil
    @State private var wheelRotation: Double = 0
    @State private var isSpinning: Bool = false
    @State private var selectedStatuses: Set<PlayType> = []
    @State private var selectedTypes: Set<PieceType> = []
    @State private var selectedBooks: Set<SuzukiBook> = []
    @State private var showFilterSheet = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager // <<< ADD THIS LINE

    private var availableBooks: [SuzukiBook] {
        let booksInSongs = Set(songs.compactMap { $0.suzukiBook })
        return SuzukiBook.allCases.filter { booksInSongs.contains($0) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Text("Spin to Decide!")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                
                Button("Filters") {
                    showFilterSheet = true
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
                
                Spacer()

                Spacer()
                ZStack(alignment: .top) {
                    WheelViewCD(songs: filteredSongs, rotation: $wheelRotation)
                        .frame(width: 320, height: 320)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 3)
                        .offset(y: -25)
                }

                Spacer()

                VStack {
                    if let song = selectedSong {
                        Text("Next up:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(song.title ?? "Unknown Song")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.accentColor)
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        Text("Spin the wheel...")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: 60)

                Button(action: spinWheel) {
                    HStack {
                        if isSpinning {
                            ProgressView().tint(.white)
                        }
                        Text(isSpinning ? "Spinning..." : "SPIN")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSpinning ? .gray : .accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .animation(.default, value: isSpinning)
                }
                .disabled(isSpinning || filteredSongs.isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .animation(.spring(), value: selectedSong)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                VStack(spacing: 24) {
                    Text("Filters")
                        .font(.title2.bold())
                        .padding(.top)
                    VStack {
                        Text("Filter by Status:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(PlayType.allCases, id: \.self) { status in
                                let isSelected = selectedStatuses.contains(status)
                                Button(action: {
                                    if isSelected {
                                        selectedStatuses.remove(status)
                                    } else {
                                        selectedStatuses.insert(status)
                                    }
                                    // Save selectedStatuses to UserDefaults using student-specific key
                                    let key = Self.key(for: studentID, base: Self.baseStatusesKey)
                                    if selectedStatuses.isEmpty {
                                        UserDefaults.standard.removeObject(forKey: key)
                                    } else {
                                        UserDefaults.standard.set(Array(selectedStatuses.map(\.rawValue)), forKey: key)
                                    }
                                }) {
                                    Text(status.rawValue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .clipShape(Capsule())
                                        .animation(.easeInOut, value: isSelected)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    VStack {
                        Text("Filter by Type:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(PieceType.allCases, id: \.self) { type in
                                let isSelected = selectedTypes.contains(type)
                                Button(action: {
                                    if isSelected {
                                        selectedTypes.remove(type)
                                    } else {
                                        selectedTypes.insert(type)
                                    }
                                    // Save selectedTypes to UserDefaults using student-specific key
                                    let key = Self.key(for: studentID, base: Self.baseTypesKey)
                                    if selectedTypes.isEmpty {
                                        UserDefaults.standard.removeObject(forKey: key)
                                    } else {
                                        UserDefaults.standard.set(Array(selectedTypes.map(\.rawValue)), forKey: key)
                                    }
                                }) {
                                    Text(type.rawValue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .clipShape(Capsule())
                                        .animation(.easeInOut, value: isSelected)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if !availableBooks.isEmpty {
                        VStack {
                            Text("Filter by Book:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                ForEach(availableBooks, id: \.self) { book in
                                    let isSelected = selectedBooks.contains(book)
                                    Button(action: {
                                        if isSelected {
                                            selectedBooks.remove(book)
                                        } else {
                                            selectedBooks.insert(book)
                                        }
                                        // Save selectedBooks to UserDefaults using student-specific key
                                        let key = Self.key(for: studentID, base: Self.baseBooksKey)
                                        if selectedBooks.isEmpty {
                                            UserDefaults.standard.removeObject(forKey: key)
                                        } else {
                                            UserDefaults.standard.set(Array(selectedBooks.map(\.rawValue)), forKey: key)
                                        }
                                    }) {
                                        Text(book.rawValue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .clipShape(Capsule())
                                            .animation(.easeInOut, value: isSelected)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Spacer()
                    Button("Done") {
                        showFilterSheet = false
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(.bottom)
                }
                .padding()
                .presentationDetents([.medium])
            }
            .onAppear {
                loadSavedFilters()
            }
        }
    }
    
    private var filteredSongs: [SongCD] {
        songs.filter { song in
            let statusOk: Bool
            if selectedStatuses.isEmpty {
                statusOk = true
            } else {
                statusOk = song.songStatus.map(selectedStatuses.contains) ?? false
            }
            let typeOk: Bool
            if selectedTypes.isEmpty {
                typeOk = true
            } else {
                typeOk = song.pieceType.map(selectedTypes.contains) ?? false
            }
            let bookOk: Bool
            if selectedBooks.isEmpty {
                bookOk = true
            } else {
                bookOk = song.suzukiBook.map(selectedBooks.contains) ?? false
            }
            return statusOk && typeOk && bookOk
        }
    }

    private func spinWheel() {
        guard !filteredSongs.isEmpty else { return }
        
        isSpinning = true
        selectedSong = nil
        
        let randomIndex = Int.random(in: 0..<filteredSongs.count)
        let winner = filteredSongs[randomIndex]
        
        let sliceAngle = 360.0 / Double(filteredSongs.count)
        let winningSliceCenter = (sliceAngle * Double(randomIndex)) + (sliceAngle / 2.0)
        
        let targetAngle = 270.0 - winningSliceCenter
        
        let currentRotation = wheelRotation.truncatingRemainder(dividingBy: 360)
        let extraSpins = Double(Int.random(in: 4...6)) * 360
        let finalTargetRotation = targetAngle - currentRotation + extraSpins
        
        let animation = Animation.timingCurve(0.1, 0.9, 0.2, 1, duration: 4.0)
        withAnimation(animation) {
            self.wheelRotation += finalTargetRotation
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) {
            self.selectedSong = winner
            self.isSpinning = false
        }
    }
    
    /// Loads saved filters from UserDefaults.
    /// Uses student-specific keys if studentID is available, else falls back to base keys.
    private func loadSavedFilters() {
        // Load selectedStatuses
        let statusesKey = Self.key(for: studentID, base: Self.baseStatusesKey)
        if let savedStatusRaw = UserDefaults.standard.array(forKey: statusesKey) as? [String] {
            let loadedStatuses = savedStatusRaw.compactMap { PlayType(rawValue: $0) }
            if !loadedStatuses.isEmpty {
                selectedStatuses = Set(loadedStatuses)
            }
        } else if studentID != nil {
            // Fallback to base key if student-specific key not found
            if let savedStatusRaw = UserDefaults.standard.array(forKey: Self.baseStatusesKey) as? [String] {
                let loadedStatuses = savedStatusRaw.compactMap { PlayType(rawValue: $0) }
                if !loadedStatuses.isEmpty {
                    selectedStatuses = Set(loadedStatuses)
                }
            }
        }
        
        // Load selectedTypes
        let typesKey = Self.key(for: studentID, base: Self.baseTypesKey)
        if let savedTypeRaw = UserDefaults.standard.array(forKey: typesKey) as? [String] {
            let loadedTypes = savedTypeRaw.compactMap { PieceType(rawValue: $0) }
            if !loadedTypes.isEmpty {
                selectedTypes = Set(loadedTypes)
            }
        } else if studentID != nil {
            // Fallback to base key if student-specific key not found
            if let savedTypeRaw = UserDefaults.standard.array(forKey: Self.baseTypesKey) as? [String] {
                let loadedTypes = savedTypeRaw.compactMap { PieceType(rawValue: $0) }
                if !loadedTypes.isEmpty {
                    selectedTypes = Set(loadedTypes)
                }
            }
        }
        
        // Load selectedBooks
        let booksKey = Self.key(for: studentID, base: Self.baseBooksKey)
        if let savedBooksRaw = UserDefaults.standard.array(forKey: booksKey) as? [String] {
            let loadedBooks = savedBooksRaw.compactMap { SuzukiBook(rawValue: $0) }
            if !loadedBooks.isEmpty {
                selectedBooks = Set(loadedBooks)
            }
        } else if studentID != nil {
            // Fallback to base key if student-specific key not found
            if let savedBooksRaw = UserDefaults.standard.array(forKey: Self.baseBooksKey) as? [String] {
                let loadedBooks = savedBooksRaw.compactMap { SuzukiBook(rawValue: $0) }
                if !loadedBooks.isEmpty {
                    selectedBooks = Set(loadedBooks)
                }
            }
        }
    }
}

private struct WheelViewCD: View {
    let songs: [SongCD]
    @Binding var rotation: Double
    private let colors: [Color] = [.red,.orange,.yellow,.green,.blue,.indigo,.purple]

    var body: some View {
        ZStack {
            ForEach(songs.indices, id: \.self) { index in
                WheelSliceCD(
                    index: index,
                    totalSlices: songs.count,
                    songTitle: songs[index].title ?? "Song",
                    color: colors[index % colors.count]
                )
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

private struct WheelSliceCD: View {
    let index: Int
    let totalSlices: Int
    let songTitle: String
    let color: Color

    var body: some View {
        let sliceAngle = 360.0 / Double(totalSlices)
        let startAngle = sliceAngle * Double(index)
        let middleAngle = startAngle + (sliceAngle / 2.0)

        GeometryReader { geo in
            let radius = geo.size.width / 2
            let center = CGPoint(x: radius, y: radius)

            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(startAngle + sliceAngle),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
            .overlay(
                Path { path in
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(startAngle + sliceAngle),
                        clockwise: false
                    )
                }.stroke(.white.opacity(0.5), lineWidth: 1)
            )

            Text(songTitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.1), radius: 1)
                .frame(width: radius * 0.95, height: 45)
                .multilineTextAlignment(.center)
                .allowsTightening(true)
                .minimumScaleFactor(0.8)
                .offset(x: radius * 0.6)
                .rotationEffect(.degrees(middleAngle))
                .position(center)
        }
    }
}
