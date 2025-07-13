import Foundation
import SwiftUI
import SwiftData
import Combine

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

// MARK: - VIEW MODEL
@MainActor
class StatsViewModel: ObservableObject {
    
    @Published var dummy: Bool = false
    
    // MARK: Properties
    private let sessions: [PracticeSession]
    
    // Monthly Stats
    let totalSessionsThisMonth: Int
    let totalPlaysThisMonth: Int
    let avgPlaysPerSession: Int
    let monthPlays: [Int: Int]
    let daysInMonth: [Int]
    
    // Weekly Stats
    let last7Days: [Date]
    let practicedDaysLast7: Int
    private let sessionDates: Set<Date>
    
    // Weekday Distribution
    let weekdayCounts: [Int: Int]
    let shortWeekdaySymbols: [String]
    
    // --- MODIFIED: Store the full Song object ---
    let mostPracticedSong: Song?
    let songNeedingPractice: Song?
    
    // All-Time Stats
    let firstPracticeDate: String
    let totalPracticeDays: Int
    
    // New properties
    let allMonths: [MonthKey]
    let monthPlayCounts: [MonthKey: [Int: Int]]
    
    // MARK: - Initializer
    init(sessions: [PracticeSession]) {
        let calendar = Calendar.current
        let today = Date()
        
        self.sessions = sessions
        
        // Build allMonths and monthPlayCounts
        let monthSet = Set(sessions.map {
            let comps = calendar.dateComponents([.year, .month], from: $0.day)
            return MonthKey(year: comps.year ?? 2000, month: comps.month ?? 1)
        })
        let monthsSorted = monthSet.sorted(by: >)
        allMonths = monthsSorted
        monthPlayCounts = Dictionary(uniqueKeysWithValues: monthsSorted.map { key in
            let filtered = sessions.filter {
                let comps = calendar.dateComponents([.year, .month], from: $0.day)
                return comps.year == key.year && comps.month == key.month
            }
            let counts = filtered.reduce(into: [Int: Int]()) { dict, session in
                let day = calendar.component(.day, from: session.day)
                let total = (session.plays ?? []).reduce(0) { $0 + $1.count }
                dict[day, default: 0] += total
            }
            return (key, counts)
        })
        
        let monthlySessions = sessions.filter { calendar.isDate($0.day, equalTo: today, toGranularity: .month) }
        
        // Monthly Calcs
        totalSessionsThisMonth = monthlySessions.count
        totalPlaysThisMonth = monthlySessions.reduce(0) { $0 + ($1.plays ?? []).reduce(0) { $0 + $1.count } }
        avgPlaysPerSession = totalSessionsThisMonth > 0 ? totalPlaysThisMonth / totalSessionsThisMonth : 0
        monthPlays = monthlySessions.reduce(into: [Int: Int]()) { counts, session in
            let day = calendar.component(.day, from: session.day)
            let total = (session.plays ?? []).reduce(0) { $0 + $1.count }
            counts[day, default: 0] += total
        }
        daysInMonth = Array(calendar.range(of: .day, in: .month, for: today) ?? 1..<31)
        
        // Weekly Calcs
        let last7 = Array((1...7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed())
        let sessionDaySet = Set(sessions.map { calendar.startOfDay(for: $0.day) })
        let practicedCount = last7.filter { date in
            sessionDaySet.contains { calendar.isDate($0, inSameDayAs: date) }
        }.count
        last7Days = last7
        sessionDates = sessionDaySet
        practicedDaysLast7 = practicedCount
        
        // Weekday Calcs
        weekdayCounts = monthlySessions.reduce(into: [Int: Int]()) { counts, session in
            let weekday = calendar.component(.weekday, from: session.day)
            counts[weekday, default: 0] += 1
        }
        shortWeekdaySymbols = calendar.shortWeekdaySymbols
        
        // --- Song Stats (Logic now finds and stores Song objects) ---
        let allPlays = sessions.compactMap(\.plays).flatMap { $0 }

        let songPlayData = allPlays.reduce(into: [Song: (count: Int, goal: Int)]()) { result, play in
            guard let song = play.song else { return }
            let goal = max(song.goalPlays ?? 1, 1)
            
            var entry = result[song, default: (count: 0, goal: goal)]
            entry.count += play.count
            result[song] = entry
        }

        mostPracticedSong = songPlayData.max(by: { $0.value.count < $1.value.count })?.key
        
        songNeedingPractice = songPlayData.min(by: {
            let progressA = Double($0.value.count) / Double($0.value.goal)
            let progressB = Double($1.value.count) / Double($1.value.goal)
            return progressA < progressB
        })?.key

        
        // All-Time Calcs
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.day) })
        totalPracticeDays = uniqueDays.count
        if let firstDay = uniqueDays.min() {
            firstPracticeDate = firstDay.formatted(date: .abbreviated, time: .omitted)
        } else {
            firstPracticeDate = "N/A"
        }
    }
    
    // MARK: - Methods
    func didPracticeOn(date: Date) -> Bool {
        sessionDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
    }
}


// MARK: - MAIN VIEW
struct StatsTabView: View {
    @StateObject private var viewModel: StatsViewModel
    
    init(sessions: [PracticeSession]) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(sessions: sessions))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 24) {
                                ForEach(viewModel.allMonths.sorted(), id: \.self) { month in
                                    HeatMapView(year: month.year, month: month.month, dayPlayCounts: viewModel.monthPlayCounts[month] ?? [:])
                                        .frame(width: 350) // consistent width for all months' heat maps
                                        .id(month)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .padding(.trailing, 20)
                        .onAppear {
                            let today = Date()
                            let comps = Calendar.current.dateComponents([.year, .month], from: today)
                            let currentMonth = MonthKey(year: comps.year ?? 2000, month: comps.month ?? 1)
                            if viewModel.allMonths.contains(currentMonth) {
                                proxy.scrollTo(currentMonth, anchor: .center)
                            }
                        }
                    }
                    WeeklyPracticeView(viewModel: viewModel)
                    MonthlySummaryView(viewModel: viewModel)
                    WeekdayChartView(viewModel: viewModel)
                    SongStatsView(viewModel: viewModel)
                    AllTimeStatsView(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle("Practice Stats")
        }
    }
}


// MARK: - SUBVIEWS
struct HeatMapView: View {
    let year: Int
    let month: Int
    let dayPlayCounts: [Int: Int]
    
    private var calendar: Calendar {
        Calendar(identifier: .gregorian)
    }
    
    private var daysInMonth: [Int] {
        let comps = DateComponents(year: year, month: month)
        let refDate = calendar.date(from: comps) ?? Date()
        let currentMonthRange = calendar.range(of: .day, in: .month, for: refDate) ?? Range(1...31)
        return Array(currentMonthRange)
    }
    
    private var firstDayDate: Date {
        calendar.date(from: DateComponents(year: year, month: month)) ?? Date()
    }
    
    private var firstWeekday: Int {
        calendar.component(.weekday, from: firstDayDate) // 1=Sunday
    }
    
    private var paddedDays: [Int?] {
        var padded = Array(repeating: nil, count: firstWeekday - 1) + daysInMonth.map { Optional($0) }
        let remainder = padded.count % 7
        if remainder != 0 {
            padded += Array(repeating: nil, count: 7 - remainder)
        }
        return padded
    }
    
    private var weekRows: [[Int?]] {
        stride(from: 0, to: paddedDays.count, by: 7).map { i in
            Array(paddedDays[i..<min(i + 7, paddedDays.count)])
        }
    }
    
    private var weekdaySymbols: [String] {
        calendar.veryShortStandaloneWeekdaySymbols
    }
    
    private var currentMonthName: String {
        let comps = DateComponents(year: year, month: month)
        let refDate = calendar.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: refDate)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Section(header: Text("Practice Heat Map (\(currentMonthName))").font(.headline).padding(.bottom, 5)) {
                VStack(spacing: 4) {
                    Text(currentMonthName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.bottom, 2)
                    // Header: S M TU W TH F S
                    HStack(spacing: 4) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    // Calendar Grid
                    ForEach(weekRows.indices, id: \.self) { rowIdx in
                        HStack(spacing: 4) {
                            ForEach(weekRows[rowIdx], id: \.self) { dayOpt in
                                if let day = dayOpt {
                                    let count = dayPlayCounts[day, default: 0]
                                    let opacity = min(Double(count) / 5.0, 1.0) * 0.8 + 0.2
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.blue.opacity(opacity))
                                        Text("\(day)")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                    }
                                    .frame(height: 35)
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Color.clear
                                        .frame(height: 35)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct WeeklyPracticeView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        Section(header: Text("Last 7 Days: Practiced on \(viewModel.practicedDaysLast7) day\(viewModel.practicedDaysLast7 == 1 ? "" : "s")").font(.headline)) {
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
}

struct MonthlySummaryView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        Section(header: Text("Monthly Snapshot").font(.headline)) {
            HStack(spacing: 12) {
                StatItem(label: "Sessions", value: "\(viewModel.totalSessionsThisMonth)", icon: "📅")
                StatItem(label: "Plays", value: "\(viewModel.totalPlaysThisMonth)", icon: "🎯")
                StatItem(label: "Avg Plays/Session", value: "\(viewModel.avgPlaysPerSession)", icon: "⚖️")
            }
        }
    }
}

struct WeekdayChartView: View {
    @ObservedObject var viewModel: StatsViewModel
    private var maxCount: CGFloat {
        CGFloat(viewModel.weekdayCounts.values.max() ?? 0)
    }

    var body: some View {
        Section(header: Text("📈 Sessions by Weekday").font(.headline)) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(1...7, id: \.self) { weekday in
                    VStack(spacing: 6) {
                        Text("\(viewModel.weekdayCounts[weekday, default: 0])")
                            .font(.caption2)
                            .fontWeight(.medium)
                        let count = CGFloat(viewModel.weekdayCounts[weekday, default: 0])
                        let barHeight = maxCount > 0 ? (count / maxCount) * 60 : 0
                        
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
}

struct SongStatsView: View {
    @ObservedObject var viewModel: StatsViewModel
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        Section(header: Text("Song Insights").font(.headline)) {
            VStack(spacing: 12) {
                if let song = viewModel.mostPracticedSong {
                    NavigationLink(destination: SongDetailView(song: song, audioManager: audioManager)) {
                        StatItem(label: "Most Practiced", value: song.title, icon: "🎵")
                    }
                    .buttonStyle(.plain)
                } else {
                    StatItem(label: "Most Practiced", value: "N/A", icon: "🎵")
                }

                if let song = viewModel.songNeedingPractice {
                    NavigationLink(destination: SongDetailView(song: song, audioManager: audioManager)) {
                        StatItem(label: "Needs Practice", value: song.title, icon: "⏳")
                    }
                    .buttonStyle(.plain)
                } else {
                    StatItem(label: "Needs Practice", value: "N/A", icon: "⏳")
                }
            }
        }
    }
}

struct AllTimeStatsView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        Section(header: Text("All-Time Stats").font(.headline)) {
            VStack(spacing: 12) {
                StatItem(label: "First Practice Date", value: viewModel.firstPracticeDate, icon: "📆")
                StatItem(label: "Total Days Practiced", value: "\(viewModel.totalPracticeDays)", icon: "🗓️")
            }
        }
    }
}

struct StatItem: View {
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
