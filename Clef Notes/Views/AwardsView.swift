import SwiftUI
import CoreData

struct AwardGroup: Identifiable {
    let id = UUID()
    let category: AwardCategory
    let awards: [Award]
}

struct AwardsView: View {
    @StateObject private var awardsManager: AwardsManager
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedAward: Award?
    @State private var lastTappedAward: Award?

    private var awardGroups: [AwardGroup] {
        let groupedDictionary = Dictionary(grouping: Award.allCases, by: { $0.category })
        return groupedDictionary.map { (category, awards) in
            AwardGroup(category: category, awards: awards)
        }.sorted { $0.category.rawValue < $1.category.rawValue }
    }

    @State private var path = NavigationPath()
    let columns = [GridItem(.adaptive(minimum: 110))]

    init(student: StudentCD, context: NSManagedObjectContext) {
        _awardsManager = StateObject(wrappedValue: AwardsManager(student: student, context: context))
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 24, pinnedViews: []) {
                            ForEach(awardGroups) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(group.category.rawValue)
                                        .font(.title2.bold())
                                        .padding(.horizontal)

                                    LazyVGrid(columns: columns, spacing: 20) {
                                        ForEach(group.awards) { award in
                                            let earnedAward = awardsManager.earnedAwards[award]
                                            let isEarned = earnedAward != nil
                                            let count = Int(earnedAward?.count ?? 0)

                                            VStack(spacing: 12) {
                                                ZStack(alignment: .topTrailing) {
                                                    Image(systemName: award.icon)
                                                        .font(.largeTitle)
                                                        .padding()
                                                        .background(isEarned ? Color.yellow.opacity(0.3) : Color(UIColor.secondarySystemGroupedBackground))
                                                        .clipShape(Circle())
                                                        .foregroundColor(isEarned ? .yellow : .secondary)

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
                                                    .lineLimit(2, reservesSpace: true)
                                            }
                                            .padding(.vertical, 8)
                                            .id(award)
                                            .onTapGesture {
                                                lastTappedAward = award
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    selectedAward = award
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top)
                        .padding(.bottom, 80)
                    }
                }
                .navigationTitle("Awards")
                .onAppear {
                    awardsManager.checkAndAwardPrizes()
                }
            }

            // ✅ Modal lives outside layout tree
            if let award = selectedAward {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedAward = nil
                    }

                AwardDetailModal(award: award) {
                    selectedAward = nil
                }
                .zIndex(1)
            }
        }
    }
}

struct AwardDetailModal: View {
    let award: Award
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: award.icon)
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text(award.rawValue)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(award.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Close") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top)
        }
        .padding(30)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10)
        .padding(40)
    }
}
