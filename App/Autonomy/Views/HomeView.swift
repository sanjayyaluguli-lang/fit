import SwiftUI
import AutonomyKit

/// Four things, in this order: how you are, what's next, one line worth
/// reading, and the quickest possible way to log. Everything else is a tab.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingCheckIn = false
    @State private var showingLog = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                readinessCard
                nextUpCard
                if let insight = model.headlineInsight {
                    insightCard(insight)
                }
                quickLogCard
                habitsCard
                if let weekStart = model.pendingReviewWeekStart {
                    reviewCard(weekStart: weekStart)
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(greeting)
        .sheet(isPresented: $showingCheckIn) { CheckInView() }
        .sheet(isPresented: $showingLog) { LogSessionView(source: .freeform) }
        .task { await model.sync() }
    }

    private var greeting: String {
        let name = model.data.profile.displayName
        return name.isEmpty ? "Today" : "Morning, \(name)"
    }

    // MARK: - Cards

    private var readinessCard: some View {
        let readiness = model.readiness
        return Card(title: "Readiness") {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let score = readiness.score {
                    Text("\(Int(score.rounded()))")
                        .font(.system(size: 46, weight: .light, design: .rounded))
                        .foregroundStyle(Theme.color(for: readiness.band))
                    Text(readiness.band?.headline ?? "")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                } else {
                    Text("No signal yet")
                        .font(.title3)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
            }

            Text(readiness.guidance)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            if !readiness.contributions.isEmpty {
                HStack(spacing: 14) {
                    ForEach(readiness.contributions, id: \.label) { contribution in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contribution.label)
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                            Text(contribution.detail)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.primaryText)
                        }
                    }
                }
            }

            if model.needsCheckIn {
                Button("How do you feel today?") { showingCheckIn = true }
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private var nextUpCard: some View {
        Card(title: "Next") {
            if let item = model.todaysScheduledItem {
                ScheduledItemRow(item: item)
            } else {
                Text("Nothing scheduled.")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Text("Pick something from your library, open a YouTube session, or just log what you did.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            HStack(spacing: 10) {
                NavigationLink("Your library") { TrainView() }
                    .buttonStyle(QuietButtonStyle())
                NavigationLink("YouTube") { YouTubeLibraryView() }
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private func insightCard(_ insight: Insight) -> some View {
        Card(title: "Worth knowing") {
            Text(insight.title)
                .font(.headline)
                .foregroundStyle(insight.tone == .caution ? Theme.warm : Theme.primaryText)
            Text(insight.body)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private var quickLogCard: some View {
        Card(title: "Quick log") {
            HStack(spacing: 10) {
                Button("Session") { showingLog = true }
                    .buttonStyle(QuietButtonStyle())
                ForEach(DayEatingRating.allCases, id: \.self) { rating in
                    Button(rating.displayName) { model.rateDay(rating) }
                        .buttonStyle(QuietButtonStyle())
                }
            }
        }
    }

    private var habitsCard: some View {
        Card(title: "Habits") {
            ForEach(model.data.habits.filter(\.isActive)) { habit in
                Button {
                    model.toggleHabit(habit)
                } label: {
                    HStack {
                        Image(systemName: model.isHabitDone(habit) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(model.isHabitDone(habit) ? Theme.accent : Theme.secondaryText)
                        Text(habit.title)
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reviewCard(weekStart: Date) -> some View {
        Card(title: "Last week") {
            Text("Four questions, five minutes.")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            NavigationLink("Review it") { WeeklyReviewView(weekStart: weekStart) }
                .buttonStyle(QuietButtonStyle())
        }
    }
}

struct ScheduledItemRow: View {
    @EnvironmentObject private var model: AppModel
    let item: ScheduledItem

    var body: some View {
        switch item.target {
        case .plan(let id):
            if let plan = model.data.plan(id) {
                NavigationLink(plan.name) { PlanDetailView(plan: plan) }
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
            } else {
                Text("Plan no longer in your library").foregroundStyle(Theme.secondaryText)
            }
        case .youtube(let id):
            if let workout = model.data.youtubeWorkout(id) {
                YouTubeRow(workout: workout)
            } else {
                Text("Video no longer saved").foregroundStyle(Theme.secondaryText)
            }
        case .collection(let id):
            if let collection = model.data.collections.first(where: { $0.id == id }) {
                Text(collection.name).font(.headline).foregroundStyle(Theme.primaryText)
            }
        case .rest:
            Text("Rest day — that's the plan, not a gap in it.")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
        }
    }
}
