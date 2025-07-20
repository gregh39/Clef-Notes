import SwiftUI
import CoreData
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

struct StatsTabViewCD: View {
    @StateObject private var viewModel: StatsViewModelCD
    @Environment(\.managedObjectContext) private var viewContext

    init(student: StudentCD) {
        _viewModel = StateObject(wrappedValue: StatsViewModelCD(student: student))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 24) {
                            ForEach(viewModel.allMonths, id: \.self) { month in
                                HeatMapViewCD(year: month.year, month: month.month, dayPlayCounts: viewModel.monthPlayCounts[month] ?? [:])
                                    .frame(width: 350).id(month)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(.trailing, 20)
                    .onAppear {
                        let today = Date()
                        let comps = Calendar.current.dateComponents([.year, .month], from: today)
                        if let currentMonth = viewModel.allMonths.first(where: { $0.year == comps.year && $0.month == comps.month }) {
                            proxy.scrollTo(currentMonth, anchor: .center)
                        }
                    }
                }
                WeeklyPracticeViewCD(viewModel: viewModel)
                MonthlySummaryViewCD(viewModel: viewModel)
                WeekdayChartViewCD(viewModel: viewModel)
                SongStatsViewCD(viewModel: viewModel)
                AllTimeStatsViewCD(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("Practice Stats")
        .onAppear {
            viewModel.setup(context: viewContext)
        }
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
    @Published var allMonths: [MonthKeyCD] = []
    @Published var monthPlayCounts: [MonthKeyCD: [Int: Int]] = [:]
    
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
        
        let monthSet = Set(sessions.map {
            let comps = calendar.dateComponents([.year, .month], from: $0.day ?? .now)
            return MonthKeyCD(year: comps.year ?? 2000, month: comps.month ?? 1)
        })
        self.allMonths = monthSet.sorted(by: >)
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
        
        let allPlays = sessions.flatMap { $0.playsArray }
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
    }
    
    func didPracticeOn(date: Date) -> Bool {
        sessionDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
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
        VStack(alignment: .leading) {
            Section(header: Text("Practice Heat Map").font(.headline).padding(.bottom, 5)) {
                VStack(spacing: 4) {
                    Text(currentMonthName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.bottom, 2)
                    HStack(spacing: 4) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol).font(.caption2).fontWeight(.bold).frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(weekRows.indices, id: \.self) { rowIdx in
                        HStack(spacing: 4) {
                            ForEach(weekRows[rowIdx], id: \.self) { dayOpt in
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
            }
        }
    }
}


private struct WeeklyPracticeViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

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

private struct MonthlySummaryViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        Section(header: Text("Monthly Snapshot").font(.headline)) {
            HStack(spacing: 12) {
                StatItemCD(label: "Sessions", value: "\(viewModel.totalSessionsThisMonth)", icon: "📅")
                StatItemCD(label: "Plays", value: "\(viewModel.totalPlaysThisMonth)", icon: "🎯")
                StatItemCD(label: "Avg Plays/Session", value: "\(viewModel.avgPlaysPerSession)", icon: "⚖️")
            }
        }
    }
}

private struct WeekdayChartViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD
    private var maxCount: CGFloat {
        CGFloat(viewModel.weekdayCounts.values.max() ?? 1)
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
}

private struct SongStatsViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        Section(header: Text("Song Insights").font(.headline)) {
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
}

private struct AllTimeStatsViewCD: View {
    @ObservedObject var viewModel: StatsViewModelCD

    var body: some View {
        Section(header: Text("All-Time Stats").font(.headline)) {
            VStack(spacing: 12) {
                StatItemCD(label: "First Practice Date", value: viewModel.firstPracticeDate, icon: "📆")
                StatItemCD(label: "Total Days Practiced", value: "\(viewModel.totalPracticeDays)", icon: "🗓️")
            }
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

