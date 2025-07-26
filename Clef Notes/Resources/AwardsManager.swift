import Foundation
import CoreData
import Combine

@MainActor
class AwardsManager: ObservableObject {
    @Published var earnedAwards: [Award: EarnedAwardCD] = [:]

    private let student: StudentCD
    private let viewContext: NSManagedObjectContext
    private let calendar = Calendar.current

    // Lazily computed properties to avoid redundant calculations
    private lazy var allSessions: [PracticeSessionCD] = student.sessionsArray
    private lazy var allSongs: [SongCD] = student.songsArray
    private lazy var allPlays: [PlayCD] = allSongs.flatMap { $0.playsArray }
    private lazy var uniqueSessionDays: Set<Date> = Set(allSessions.map { calendar.startOfDay(for: $0.day ?? .distantPast) })

    init(student: StudentCD, context: NSManagedObjectContext) {
        self.student = student
        self.viewContext = context
        
        // Load the initial set of earned awards into the dictionary
        let awards = student.earnedAwardsArray
        self.earnedAwards = Dictionary(uniqueKeysWithValues: awards.compactMap {
            guard let awardEnum = $0.award else { return nil }
            return (awardEnum, $0)
        })
    }

    // This function now updates the @Published property, triggering a UI refresh.
    func checkAndAwardPrizes() {
        var didUpdate = false
        for award in Award.allCases {
            let currentProgress = calculateProgress(for: award)
            
            if let existingAward = earnedAwards[award] {
                // If the award is repeatable and the user has made new progress
                if award.isRepeatable && currentProgress > existingAward.count {
                    existingAward.count = Int64(currentProgress)
                    existingAward.dateWon = Date()
                    didUpdate = true
                }
            } else if currentProgress > 0 {
                // If the award has never been won before
                let newAward = createEarnedAward(for: award, count: currentProgress)
                earnedAwards[award] = newAward
                didUpdate = true
            }
        }
        
        if didUpdate {
            try? viewContext.save()
            // Manually trigger a refresh for the view
            objectWillChange.send()
        }
    }

    private func createEarnedAward(for award: Award, count: Int) -> EarnedAwardCD {
        let earnedAward = EarnedAwardCD(context: viewContext)
        earnedAward.awardRawValue = award.rawValue
        earnedAward.dateWon = Date()
        earnedAward.student = student
        earnedAward.count = Int64(count)
        return earnedAward
    }

    // This function calculates the current "score" for a given award.
    private func calculateProgress(for award: Award) -> Int {
        switch award {
        case .firstSession:
            return allSessions.isEmpty ? 0 : 1
        
        case .sevenDayStreak, .thirtyDayStreak:
            // This is now just a one-time achievement for reaching the streak
            let streak = calculateLongestStreak()
            if award == .sevenDayStreak && streak >= 7 { return 1 }
            if award == .thirtyDayStreak && streak >= 30 { return 1 }
            return 0
            
        case .perfectWeek:
            // Counts how many unique calendar weeks had 7 practice days
            let weeksWith7Days = Dictionary(grouping: uniqueSessionDays, by: { calendar.component(.weekOfYear, from: $0) })
                .values
                .filter { $0.count == 7 }
            return weeksWith7Days.count

        case .hundredPlays:
            return allPlays.reduce(0) { $0 + Int($1.count) } / 100
            
        case .virtuosoVolume:
            return allPlays.reduce(0) { $0 + Int($1.count) } / 500

        case .songMastery:
            // Counts how many unique songs have been mastered
            return allSongs.filter { $0.goalPlays > 0 && $0.totalGoalPlayCount >= $0.goalPlays }.count
            
        // --- Add logic for other repeatable awards here ---
        default:
            // For non-repeatable awards, just return 1 if earned, 0 otherwise
            return check(award: award) ? 1 : 0
        }
    }
    
    private func check(award: Award) -> Bool {
        // ... (This function now only handles the simple, non-repeatable awards)
        switch award {
        case .weekendWarrior: return checkWeekendWarrior()
        case .repertoireBuilder: return allSongs.count >= 10
        case .dedicatedHour: return allSessions.contains { $0.durationMinutes >= 60 }
        case .marathonMusician: return allSessions.reduce(0) { $0 + $1.durationMinutes } >= 600
        case .wellRounded: return allSessions.contains { Set($0.playsArray.compactMap { $0.song?.pieceType }).isSuperset(of: [.song, .scale, .exercise]) }
        case .composerCollector: return Set(allSongs.compactMap { $0.composer?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }).count >= 5
        case .doodlePad: return student.notesArray.contains { $0.drawing != nil && !$0.drawing!.isEmpty }
        case .recordKeeper: return !student.audioRecordingsArray.isEmpty
        default: return false
        }
    }
    
    // MARK: - Helper Calculation Functions

    private func calculateLongestStreak() -> Int {
        guard !uniqueSessionDays.isEmpty else { return 0 }
        
        let sortedDates = uniqueSessionDays.sorted()
        var longestStreak = 0
        var currentStreak = 0
        
        for i in 0..<sortedDates.count {
            if i == 0 {
                currentStreak = 1
            } else {
                let diff = calendar.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day
                if diff == 1 {
                    currentStreak += 1
                } else {
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                }
            }
        }
        longestStreak = max(longestStreak, currentStreak)
        return longestStreak
    }
    
    private func checkPerfectWeek() -> Bool {
        let sessionWeekdays = Dictionary(grouping: uniqueSessionDays, by: { calendar.component(.weekOfYear, from: $0) })
        
        for (_, daysInWeek) in sessionWeekdays {
            if Set(daysInWeek.map { calendar.component(.weekday, from: $0) }).count == 7 {
                return true
            }
        }
        return false
    }
    
    private func checkWeekendWarrior() -> Bool {
        let sessionWeekdays = Dictionary(grouping: uniqueSessionDays, by: { calendar.component(.weekOfYear, from: $0) })
        
        for (_, daysInWeek) in sessionWeekdays {
            let weekdays = Set(daysInWeek.map { calendar.component(.weekday, from: $0) })
            // 1 = Sunday, 7 = Saturday in Gregorian calendar
            if weekdays.contains(1) && weekdays.contains(7) {
                return true
            }
        }
        return false
    }
}
