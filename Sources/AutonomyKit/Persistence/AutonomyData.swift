import Foundation

/// The entire local database as one Codable document.
///
/// One user, a few thousand rows a year — a single file that loads into memory
/// is faster than a database and, more importantly, is trivially exportable and
/// readable by the owner in ten years. `schemaVersion` exists so migrations
/// stay possible.
public struct AutonomyData: Codable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var profile: UserProfile
    public var exercises: [Exercise]
    public var plans: [WorkoutPlan]
    public var sessions: [WorkoutSession]
    public var youtubeWorkouts: [YouTubeWorkout]
    public var collections: [YouTubeCollection]
    public var healthDays: [HealthDaily]
    public var recovery: [RecoverySnapshot]
    public var checkIns: [SubjectiveCheckIn]
    public var nutrition: [NutritionEntry]
    public var mealTemplates: [MealTemplate]
    public var habits: [Habit]
    public var habitLogs: [HabitLog]
    public var bodyMetrics: [BodyMetric]
    public var photos: [ProgressPhoto]
    public var reviews: [WeeklyReview]
    /// Scheduled items: plan or collection assigned to a date. Kept loose on
    /// purpose — a schedule is a suggestion the owner can ignore.
    public var schedule: [ScheduledItem]

    public init(
        schemaVersion: Int = AutonomyData.currentSchemaVersion,
        profile: UserProfile = UserProfile(),
        exercises: [Exercise] = [],
        plans: [WorkoutPlan] = [],
        sessions: [WorkoutSession] = [],
        youtubeWorkouts: [YouTubeWorkout] = [],
        collections: [YouTubeCollection] = [],
        healthDays: [HealthDaily] = [],
        recovery: [RecoverySnapshot] = [],
        checkIns: [SubjectiveCheckIn] = [],
        nutrition: [NutritionEntry] = [],
        mealTemplates: [MealTemplate] = [],
        habits: [Habit] = [],
        habitLogs: [HabitLog] = [],
        bodyMetrics: [BodyMetric] = [],
        photos: [ProgressPhoto] = [],
        reviews: [WeeklyReview] = [],
        schedule: [ScheduledItem] = []
    ) {
        self.schemaVersion = schemaVersion
        self.profile = profile
        self.exercises = exercises
        self.plans = plans
        self.sessions = sessions
        self.youtubeWorkouts = youtubeWorkouts
        self.collections = collections
        self.healthDays = healthDays
        self.recovery = recovery
        self.checkIns = checkIns
        self.nutrition = nutrition
        self.mealTemplates = mealTemplates
        self.habits = habits
        self.habitLogs = habitLogs
        self.bodyMetrics = bodyMetrics
        self.photos = photos
        self.reviews = reviews
        self.schedule = schedule
    }

    /// First-run contents: a small exercise seed and the habits most worth
    /// tracking. No starter program — the owner picks or writes one.
    public static func firstRun(profile: UserProfile = UserProfile()) -> AutonomyData {
        AutonomyData(
            profile: profile,
            exercises: ExerciseCatalog.seed(),
            habits: [
                Habit(kind: .protein),
                Habit(kind: .steps, target: Double(profile.targetStepsPerDay), unit: "steps"),
                Habit(kind: .bedtime),
                Habit(kind: .mobility, target: 10, unit: "min")
            ]
        )
    }
}

public enum ScheduledTarget: Codable, Hashable, Sendable {
    case plan(UUID)
    case collection(UUID)
    case youtube(UUID)
    case rest
}

public struct ScheduledItem: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var target: ScheduledTarget
    public var note: String

    public init(id: UUID = UUID(), date: Date, target: ScheduledTarget, note: String = "") {
        self.id = id
        self.date = date
        self.target = target
        self.note = note
    }
}

// MARK: - Convenience lookups

public extension AutonomyData {
    func exercise(_ id: UUID) -> Exercise? { exercises.first { $0.id == id } }
    func plan(_ id: UUID) -> WorkoutPlan? { plans.first { $0.id == id } }
    func youtubeWorkout(_ id: UUID) -> YouTubeWorkout? { youtubeWorkouts.first { $0.id == id } }

    func healthDay(on date: Date, calendar: Calendar = .current) -> HealthDaily? {
        healthDays.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func recoverySnapshot(on date: Date, calendar: Calendar = .current) -> RecoverySnapshot? {
        recovery.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func checkIn(on date: Date, calendar: Calendar = .current) -> SubjectiveCheckIn? {
        checkIns.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func scheduled(on date: Date, calendar: Calendar = .current) -> ScheduledItem? {
        schedule.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func sessions(on date: Date, calendar: Calendar = .current) -> [WorkoutSession] {
        sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Today's readiness, assembled from whatever happens to be available.
    func readiness(on date: Date = Date(), calendar: Calendar = .current) -> Readiness {
        ReadinessEngine.evaluate(
            date: date,
            recovery: recoverySnapshot(on: date, calendar: calendar),
            health: healthDay(on: date, calendar: calendar),
            checkIn: checkIn(on: date, calendar: calendar),
            baseline: PhysiologyBaseline.trailing(
                from: healthDays,
                recovery: recovery,
                asOf: date,
                calendar: calendar
            )
        )
    }

    func independence(asOf date: Date = Date()) -> IndependenceReport {
        IndependenceScore.evaluate(
            sessions: sessions,
            plans: plans,
            exercises: exercises,
            reviews: reviews,
            asOf: date
        )
    }
}
