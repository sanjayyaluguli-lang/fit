import Foundation
import AutonomyKit

/// The app's single source of truth. Holds one in-memory copy of the data,
/// writes through to the store, and owns the (optional) integrations.
///
/// Everything here is main-actor: with one user and a few thousand rows there
/// is no reason to make the UI reason about concurrency.
@MainActor
final class AppModel: ObservableObject {

    @Published private(set) var data: AutonomyData
    @Published private(set) var isSyncing = false
    @Published var syncError: String?

    /// Nil only when the data file could not be opened. The app stays usable in
    /// memory rather than refusing to start, and Settings says so.
    private let store: AutonomyStore?
    private var healthProviders: [HealthDataProvider]
    private var recoveryProviders: [RecoveryDataProvider]

    init(
        store: AutonomyStore?,
        data: AutonomyData,
        healthProviders: [HealthDataProvider] = [],
        recoveryProviders: [RecoveryDataProvider] = []
    ) {
        self.store = store
        self.data = data
        self.healthProviders = healthProviders
        self.recoveryProviders = recoveryProviders
    }

    static func live() async -> AppModel {
        do {
            let url = try AutonomyStore.defaultFileURL()
            let store = try AutonomyStore(fileURL: url)
            let data = await store.data
            return AppModel(
                store: store,
                data: data,
                healthProviders: [HealthKitProvider()],
                recoveryProviders: [WhoopProvider()]
            )
        } catch {
            // A store that can't open is not a reason to lose the session: run
            // in memory, write nothing, and say so in Settings. Silently
            // resetting someone's training history would be worse than failing.
            let model = AppModel(store: nil, data: AutonomyData.firstRun())
            model.syncError = "Couldn't open your data file, so nothing is being saved this session. Your existing file was left untouched. (\(error))"
            return model
        }
    }

    // MARK: - Writing

    func edit(_ mutation: (inout AutonomyData) -> Void) {
        mutation(&data)
        guard let store else { return }
        let snapshot = data
        Task { await store.update { $0 = snapshot } }
    }

    // MARK: - Derived state used by the home screen

    var today: Date { Date() }

    var readiness: Readiness { data.readiness(on: today) }

    var independence: IndependenceReport { data.independence() }

    var headlineInsight: Insight? { InsightEngine.headline(from: data) }

    var todaysScheduledItem: ScheduledItem? { data.scheduled(on: today) }

    var recentSessions: [WorkoutSession] {
        data.sessions.sorted { $0.date > $1.date }
    }

    var needsCheckIn: Bool { data.checkIn(on: today) == nil }

    /// Last week's review, if it hasn't been done. Surfaced once, never nagged.
    var pendingReviewWeekStart: Date? {
        let calendar = Calendar.current
        guard !data.sessions.isEmpty,
              let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek)
        else { return nil }
        let done = data.reviews.contains {
            calendar.isDate($0.weekStart, inSameDayAs: lastWeek) && $0.isComplete
        }
        return done ? nil : lastWeek
    }

    // MARK: - Logging

    func logCheckIn(energy: Int, stress: Int?, note: String) {
        edit { data in
            data.checkIns.removeAll { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
            data.checkIns.append(
                SubjectiveCheckIn(date: Date(), energy: energy, stress: stress, note: note)
            )
        }
    }

    func log(_ session: WorkoutSession) {
        edit { data in
            data.sessions.append(session)
            if case .youtube(let videoID) = session.source,
               let index = data.youtubeWorkouts.firstIndex(where: { $0.videoID == videoID }) {
                data.youtubeWorkouts[index].timesCompleted += 1
                data.youtubeWorkouts[index].lastCompletedAt = session.date
                if let rating = session.rating {
                    data.youtubeWorkouts[index].rating = rating
                }
            }
        }
        Task { await exportToHealth(session) }
    }

    func newRecords(for session: WorkoutSession) -> [PersonalRecord] {
        ProgressiveOverload.newRecords(
            in: session,
            priorSessions: data.sessions.filter { $0.id != session.id && $0.date <= session.date }
        )
    }

    func rateDay(_ rating: DayEatingRating, note: String = "") {
        edit { data in
            data.nutrition.removeAll {
                Calendar.current.isDate($0.date, inSameDayAs: Date()) && $0.photoFileName == nil
            }
            data.nutrition.append(NutritionEntry(date: Date(), rating: rating, note: note))
        }
    }

    func toggleHabit(_ habit: Habit, on date: Date = Date(), value: Double? = nil) {
        edit { data in
            if let index = data.habitLogs.firstIndex(where: {
                $0.habitID == habit.id && Calendar.current.isDate($0.date, inSameDayAs: date)
            }) {
                data.habitLogs[index].completed.toggle()
                data.habitLogs[index].value = value
            } else {
                data.habitLogs.append(HabitLog(habitID: habit.id, date: date, completed: true, value: value))
            }
        }
    }

    func isHabitDone(_ habit: Habit, on date: Date = Date()) -> Bool {
        data.habitLogs.contains {
            $0.habitID == habit.id && $0.completed && Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    // MARK: - Integrations

    func connectedTools() -> [ConnectedTool] {
        (healthProviders.filter(\.isAvailable).map(\.tool) + recoveryProviders.filter(\.isAvailable).map(\.tool))
    }

    /// Pulls the last `days` of everything the owner has connected. Safe to call
    /// on every foreground: providers return whole days and merging never
    /// overwrites manual entries.
    func sync(days: Int = 30) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        var failures: [String] = []

        for provider in healthProviders where provider.isAvailable {
            do {
                let metrics = try await provider.dailyMetrics(from: start, to: end)
                let sessions = try await provider.importedSessions(from: start, to: end)
                edit { data in
                    data.healthDays = SyncCoordinator.merge(metrics, into: data.healthDays)
                    let known = Set(data.sessions.map(\.id))
                    data.sessions.append(contentsOf: sessions.filter { !known.contains($0.id) })
                    data.bodyMetrics = Self.mergeWeights(from: metrics, into: data.bodyMetrics)
                }
            } catch {
                failures.append("\(provider.tool.rawValue): \(error.localizedDescription)")
            }
        }

        for provider in recoveryProviders where provider.isAvailable {
            do {
                let snapshots = try await provider.recovery(from: start, to: end)
                edit { data in
                    data.recovery = SyncCoordinator.merge(snapshots, into: data.recovery)
                }
            } catch {
                failures.append("\(provider.tool.rawValue): \(error.localizedDescription)")
            }
        }

        syncError = failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

    private func exportToHealth(_ session: WorkoutSession) async {
        for provider in healthProviders where provider.isAvailable {
            try? await provider.export(session: session)
        }
    }

    private static func mergeWeights(from metrics: [HealthDaily], into existing: [BodyMetric]) -> [BodyMetric] {
        var result = existing
        for day in metrics {
            guard let weight = day.weightKg else { continue }
            let alreadyKnown = result.contains {
                $0.kind == .weightKg && Calendar.current.isDate($0.date, inSameDayAs: day.date)
            }
            guard !alreadyKnown else { continue }
            result.append(BodyMetric(date: day.date, kind: .weightKg, value: weight, importedFromHealth: true))
        }
        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Export

    func exportBundle() throws -> Exporter.Bundle {
        try Exporter.bundle(data)
    }
}
