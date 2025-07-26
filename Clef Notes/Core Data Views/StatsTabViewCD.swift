// Clef Notes/Core Data Views/StatsTabViewCD.swift

import SwiftUI
import CoreData
import Combine

// --- THIS IS THE FIX: New struct for the piece type chart ---
struct PieceTypeStat: Identifiable {
    let id = UUID()
    let type: PieceType
    let count: Int
    let color: Color
}

struct MonthKey: Hashable, Comparable {
    let year: Int
    let month: Int
    
    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        lhs.year != rhs.year ? lhs.year < rhs.year : lhs.month < rhs.month
    }
    
    var displayString: String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

struct StatsTabViewCD: View {
    @StateObject private var viewModel: StatsViewModelCD
    @Environment(\.managedObjectContext) private var viewContext
    @State private var path = NavigationPath()


    init(student: StudentCD) {
        _viewModel = StateObject(wrappedValue: StatsViewModelCD(student: student))
    }
    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    StreakViewCD(viewModel: viewModel)
                }
                
                Section(header: Text("Practice Heat Map")) {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(viewModel.allMonths, id: \.self) { month in
                                    HeatMapViewCD(year: month.year, month: month.month, dayPlayCounts: viewModel.monthPlayCounts[month] ?? [:])
                                        .id(month)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .onAppear {
                            proxy.scrollTo(viewModel.allMonths.last, anchor: .trailing)
                        }
                    }
                }
                
                Section(header: Text("Last 7 Days: Practiced on \(viewModel.practicedDaysLast7) day\(viewModel.practicedDaysLast7 == 1 ? "" : "s")")) {
                    WeeklyPracticeViewCD(viewModel: viewModel)
                }
                
                Section(header: Text("Monthly Snapshot")) {
                    MonthlySummaryViewCD(viewModel: viewModel)
                }
                
                Section(header: Text("📈 Sessions by Weekday")) {
                    WeekdayChartViewCD(viewModel: viewModel)
                }
                
                // --- THIS IS THE FIX: New section for piece type breakdown ---
                Section(header: Text("Practice Breakdown")) {
                    PieceTypeChartViewCD(viewModel: viewModel)
                }
                
                Section(header: Text("Song Insights")) {
                    SongStatsViewCD(viewModel: viewModel)
                }
                
                Section(header: Text("All-Time Stats")) {
                    AllTimeStatsViewCD(viewModel: viewModel)
                }
            }
            .onAppear {
                viewModel.setup(context: viewContext)
            }
        }
        .navigationTitle("Stats")
    }
}

@MainActor
class StatsViewModelCD: ObservableObject {
    private let student: StudentCD
    private var cancellables = Set<AnyCancellable>()

    @Published var totalSessionsThisMonth: Int = 0
    @Published var totalPlaysThisMonth: Int = 0
    @Published var avgPlaysPerSession: Int = 0
    @Published var last7Days: [Date] = []
    @Published var practicedDaysLast7: Int = 0
    @Published var weekdayCounts: [Int: Int] = [:]
    @Published var shortWeekdaySymbols: [String] = []
    @Published var mostPracticedSong: SongCD? = nil
    @Published var songNeedingPractice: SongCD? = nil
    @Published var firstPracticeDate: String = "N/A"
    @Published var totalPracticeDays: Int = 0
    // --- THIS IS THE FIX: New properties for new stats ---
    @Published var totalPracticeTime: String = "0m"
    @Published var pieceTypeDistribution: [PieceTypeStat] = []
    
    @Published var allMonths: [MonthKeyCD] = []
    @Published var monthPlayCounts: [MonthKeyCD: [Int: Int]] = [:]
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    
    private var sessionDates: Set<Date> = []

    init(student: StudentCD) {
        self.student = student
        self.shortWeekdaySymbols = Calendar.current.shortWeekdaySymbols
    }
    
    func setup(context: NSManagedObjectContext) {
        recalculate()

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculate()
            }
            .store(in: &cancellables)
    }
    
    private func recalculate() {
        let sessions = student.sessionsArray
        let calendar = Calendar.current
        let today = Date()
        
        let allPlays = sessions.flatMap { $0.playsArray }

        // --- THIS IS THE FIX: Calculation for new stats ---
        calculateTotalPracticeTime(from: sessions)
        calculatePieceTypeDistribution(from: allPlays)
        
        let monthSet = Set(sessions.map {
            let comps = calendar.dateComponents([.year, .month], from: $0.day ?? .now)
            return MonthKeyCD(year: comps.year ?? 2000, month: comps.month ?? 1)
        })
        self.allMonths = monthSet.sorted()
        self.monthPlayCounts = Dictionary(uniqueKeysWithValues: allMonths.map { key in
            let filtered = sessions.filter {
                let comps = calendar.dateComponents([.year, .month], from: $0.day ?? .now)
                return comps.year == key.year && comps.month == key.month
            }
            let counts = filtered.reduce(into: [Int: Int]()) { dict, session in
                let day = calendar.component(.day, from: session.day ?? .now)
                let total = session.playsArray.reduce(0) { $0 + Int($1.count) }
                dict[day, default: 0] += total
            }
            return (key, counts)
        })
        
        let monthlySessions = sessions.filter { calendar.isDate($0.day ?? .distantPast, equalTo: today, toGranularity: .month) }
        self.totalSessionsThisMonth = monthlySessions.count
        self.totalPlaysThisMonth = monthlySessions.reduce(0) { $0 + $1.playsArray.reduce(0) { $0 + Int($1.count) } }
        
        if totalSessionsThisMonth > 0 {
            self.avgPlaysPerSession = totalPlaysThisMonth / totalSessionsThisMonth
        } else {
            self.avgPlaysPerSession = 0
        }
        
        self.last7Days = Array((0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed())
        let sessionDaySet = Set(sessions.map { calendar.startOfDay(for: $0.day ?? .distantPast) })
        self.practicedDaysLast7 = last7Days.filter { date in
            sessionDaySet.contains { calendar.isDate($0, inSameDayAs: date) }
        }.count
        self.sessionDates = sessionDaySet
        
        self.weekdayCounts = monthlySessions.reduce(into: [Int: Int]()) { counts, session in
            let weekday = calendar.component(.weekday, from: session.day ?? .now)
            counts[weekday, default: 0] += 1
        }
        
        let songPlayData = allPlays.reduce(into: [SongCD: (count: Int, goal: Int)]()) { result, play in
            guard let song = play.song else { return }
            let goal = max(Int(song.goalPlays), 1)
            
            var entry = result[song, default: (count: 0, goal: goal)]
            entry.count += Int(play.count)
            result[song] = entry
        }
        self.mostPracticedSong = songPlayData.max(by: { $0.value.count < $1.value.count })?.key
        self.songNeedingPractice = songPlayData.min(by: {
            let progressA = Double($0.value.count) / Double($0.value.goal)
            let progressB = Double($1.value.count) / Double($1.value.goal)
            return progressA < progressB
        })?.key
        
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.day ?? .distantPast) })
        self.totalPracticeDays = uniqueDays.count
        if let firstDay = uniqueDays.min() {
            self.firstPracticeDate = firstDay.formatted(date: .abbreviated, time: .omitted)
        } else {
            self.firstPracticeDate = "N/A"
        }
        
        let sortedDates = sessionDaySet.sorted(by: >)
        (currentStreak, longestStreak) = calculateStreaks(from: sortedDates)
    }

    // --- THIS IS THE FIX: New calculation functions ---
    private func calculateTotalPracticeTime(from sessions: [PracticeSessionCD]) {
        let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        if hours > 0 {
            self.totalPracticeTime = "\(hours)h \(minutes)m"
        } else {
            self.totalPracticeTime = "\(minutes)m"
        }
    }

    private func calculatePieceTypeDistribution(from plays: [PlayCD]) {
        let counts = plays.reduce(into: [PieceType: Int]()) { counts, play in
            let type = play.song?.pieceType ?? .song
            counts[type, default: 0] += Int(play.count)
        }
        
        let colors: [PieceType: Color] = [.song: .blue, .scale: .green, .warmUp: .orange, .exercise: .purple]
        
        self.pieceTypeDistribution = counts.map { type, count in
            PieceTypeStat(type: type, count: count, color: colors[type] ?? .gray)
        }.sorted { $0.count > $1.count }
    }

    private func calculateStreaks(from sortedDates: [Date]) -> (current: Int, longest: Int) {
        guard !sortedDates.isEmpty else { return (0, 0) }
        
        let calendar = Calendar.current
        var current = 0
        var longest = 0
        
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let practicedToday = sortedDates.contains(today)
        let practicedYesterday = sortedDates.contains(yesterday)
        
        var dateToCheck: Date
        
        if practicedToday {
            dateToCheck = today
        } else if practicedYesterday {
            dateToCheck = yesterday
        } else {
            dateToCheck = .distantFuture
        }

        if dateToCheck != .distantFuture {
            for date in sortedDates {
                if date == dateToCheck {
                    current += 1
                    dateToCheck = calendar.date(byAdding: .day, value: -1, to: dateToCheck)!
                } else if date < dateToCheck {
                    break
                }
            }
        }
        
        var streak = 0
        var lastDate: Date? = nil
        for date in sortedDates.reversed() {
            if let previousDate = lastDate {
                let diff = calendar.dateComponents([.day], from: previousDate, to: date).day ?? 0
                if diff == 1 {
                    streak += 1
                } else {
                    longest = max(longest, streak)
                    streak = 1
                }
            } else {
                streak = 1
            }
            lastDate = date
        }
        longest = max(longest, streak)
        
        return (current, longest)
    }
    
    func didPracticeOn(date: Date) -> Bool {
        sessionDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
    }
}

private struct StreakViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        HStack(spacing: 16) {
            StatItemCD(label: "Current Streak", value: "\(viewModel.currentStreak) Days", icon: "🔥")
            StatItemCD(label: "Longest Streak", value: "\(viewModel.longestStreak) Days", icon: "🏆")
        }
    }
}


struct MonthKeyCD: Hashable, Comparable {
    let year: Int
    let month: Int
    
    static func < (lhs: MonthKeyCD, rhs: MonthKeyCD) -> Bool {
        lhs.year != rhs.year ? lhs.year < rhs.year : lhs.month < rhs.month
    }
}

private struct HeatMapViewCD: View {
    let year: Int
    let month: Int
    let dayPlayCounts: [Int: Int]
    
    private var calendar: Calendar { Calendar(identifier: .gregorian) }
    
    private var daysInMonth: [Int] {
        let comps = DateComponents(year: year, month: month)
        let refDate = calendar.date(from: comps) ?? Date()
        return Array(calendar.range(of: .day, in: .month, for: refDate) ?? Range(1...31))
    }
    
    private var firstDayDate: Date { calendar.date(from: DateComponents(year: year, month: month)) ?? Date() }
    
    private var firstWeekday: Int { calendar.component(.weekday, from: firstDayDate) }
    
    private var paddedDays: [Int?] {
        var padded = Array(repeating: nil, count: firstWeekday - 1) + daysInMonth.map { Optional($0) }
        if padded.count % 7 != 0 {
            padded += Array(repeating: nil, count: 7 - (padded.count % 7))
        }
        return padded
    }
    
    private var weekRows: [[Int?]] {
        stride(from: 0, to: paddedDays.count, by: 7).map {
            Array(paddedDays[$0..<min($0 + 7, paddedDays.count)])
        }
    }
    
    private var weekdaySymbols: [String] { calendar.veryShortStandaloneWeekdaySymbols }
    
    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: firstDayDate)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(currentMonthName)
                .font(.headline)
                .padding(.bottom, 2)
            HStack(spacing: 4) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index]).font(.caption2).fontWeight(.bold).frame(maxWidth: .infinity)
                }
            }
            ForEach(weekRows.indices, id: \.self) { rowIdx in
                HStack(spacing: 4) {
                    ForEach(weekRows[rowIdx].indices, id: \.self) { dayIndex in
                        let dayOpt = weekRows[rowIdx][dayIndex]
                        if let day = dayOpt {
                            let count = dayPlayCounts[day, default: 0]
                            let opacity = count > 0 ? min(Double(count) / 5.0, 1.0) * 0.8 + 0.2 : 0.1
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(opacity))
                                if count > 0 {
                                    Text("\(day)").font(.caption).foregroundColor(.white).fontWeight(.bold)
                                }
                            }
                            .frame(height: 35).frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(height: 35).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .frame(width: 320)
    }
}


private struct WeeklyPracticeViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.last7Days, id: \.self) { date in
                VStack(spacing: 8) {
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ZStack {
                        Circle()
                            .fill(viewModel.didPracticeOn(date: date) ? Color.green : Color(UIColor.systemGray5))
                            .frame(width: 35, height: 35)
                        Text(date.formatted(.dateTime.day()))
                            .font(.caption)
                            .foregroundColor(viewModel.didPracticeOn(date: date) ? .white : .primary)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct MonthlySummaryViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        HStack(spacing: 12) {
            StatItemCD(label: "Sessions", value: "\(viewModel.totalSessionsThisMonth)", icon: "📅")
            StatItemCD(label: "Plays", value: "\(viewModel.totalPlaysThisMonth)", icon: "🎯")
            StatItemCD(label: "Avg Plays/Session", value: "\(viewModel.avgPlaysPerSession)", icon: "⚖️")
        }
    }
}

private struct WeekdayChartViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD
    private var maxCount: CGFloat {
        CGFloat(viewModel.weekdayCounts.values.max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(1...7, id: \.self) { weekday in
                VStack(spacing: 6) {
                    Text("\(viewModel.weekdayCounts[weekday, default: 0])")
                        .font(.caption2)
                        .fontWeight(.medium)
                    let count = CGFloat(viewModel.weekdayCounts[weekday, default: 0])
                    let barHeight = (count / maxCount) * 60
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple.gradient)
                        .frame(height: max(barHeight, 2))
                    Text(viewModel.shortWeekdaySymbols[weekday - 1])
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 5)
    }
}

// --- THIS IS THE FIX: New chart view ---
private struct PieceTypeChartViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD
    private var totalPlays: Int {
        viewModel.pieceTypeDistribution.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.pieceTypeDistribution) { stat in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stat.type.rawValue)
                            .font(.caption.bold())
                        Spacer()
                        Text("\(stat.count) plays")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: Double(stat.count), total: Double(totalPlays))
                        .tint(stat.color)
                }
            }
        }
    }
}


private struct SongStatsViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        VStack(spacing: 12) {
            if let song = viewModel.mostPracticedSong {
                NavigationLink(value: song) {
                    StatItemCD(label: "Most Practiced", value: song.title ?? "N/A", icon: "🎵")
                }
                .buttonStyle(.plain)
            } else {
                StatItemCD(label: "Most Practiced", value: "N/A", icon: "🎵")
            }

            if let song = viewModel.songNeedingPractice {
                NavigationLink(value: song) {
                    StatItemCD(label: "Needs Practice", value: song.title ?? "N/A", icon: "⏳")
                }
                .buttonStyle(.plain)
            } else {
                StatItemCD(label: "Needs Practice", value: "N/A", icon: "⏳")
            }
        }
    }
}

private struct AllTimeStatsViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        // --- THIS IS THE FIX: Added total practice time ---
        VStack(spacing: 12) {
            StatItemCD(label: "First Practice Date", value: viewModel.firstPracticeDate, icon: "📆")
            StatItemCD(label: "Total Days Practiced", value: "\(viewModel.totalPracticeDays)", icon: "🗓️")
            StatItemCD(label: "Total Practice Time", value: viewModel.totalPracticeTime, icon: "⏱️")
        }
    }
}

private struct StatItemCD: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 15) {
            Text(icon)
                .font(.title2)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

