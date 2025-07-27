import SwiftUI
import CoreData

// A helper struct to hold the grouped data for the view
struct AwardGroup: Identifiable {
    let id = UUID()
    let category: AwardCategory
    let awards: [Award]
}

struct AwardsView: View {
    // This view now owns its AwardsManager.
    @StateObject private var awardsManager: AwardsManager
    @Environment(\.managedObjectContext) private var viewContext
    
    // This computed property groups all awards by their category
    private var awardGroups: [AwardGroup] {
        let groupedDictionary = Dictionary(grouping: Award.allCases, by: { $0.category })
        
        return groupedDictionary.map { (category, awards) in
            AwardGroup(category: category, awards: awards)
        }.sorted { $0.category.rawValue < $1.category.rawValue }
    }

    @State private var path = NavigationPath()

    let columns = [GridItem(.adaptive(minimum: 110))]

    // The initializer is now required to create the StateObject with the student and context.
    init(student: StudentCD, context: NSManagedObjectContext) {
        _awardsManager = StateObject(wrappedValue: AwardsManager(student: student, context: context))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(awardGroups) { group in
                    Section(header: Text(group.category.rawValue).font(.title2.bold()).padding(.vertical, 4)) {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(group.awards) { award in
                                let earnedAward = awardsManager.earnedAwards[award]
                                let isEarned = earnedAward != nil
                                let count = Int(earnedAward?.count ?? 0)
                                
                                VStack(spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: award.icon)
                                            .font(.largeTitle)
                                            .padding()
                                            .background(isEarned ? Color.yellow.opacity(0.3) : Color(UIColor.secondarySystemGroupedBackground))
                                            .clipShape(Circle())
                                            .foregroundColor(isEarned ? .yellow : .secondary)
                                        
                                        // Show a count badge for repeatable awards won more than once
                                        if award.isRepeatable && count > 1 {
                                            Text("\(count)")
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                                .padding(6)
                                                .background(Color.red)
                                                .clipShape(Circle())
                                                .offset(x: 5, y: -5)
                                        }
                                    }
                                    
                                    Text(award.rawValue)
                                        .font(.headline)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                    
                                    Text(award.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3, reservesSpace: true)
                                }
                                .frame(height: 200)
                            }
                        }
                        .padding(.vertical)
                    }
                }
                
            }
            .navigationTitle("Awards")
            .listStyle(.insetGrouped)
            .onAppear {
                // The check is triggered here, and it updates the
                // @Published property, which the view is subscribed to.
                awardsManager.checkAndAwardPrizes()
            }
        }
    }
}
