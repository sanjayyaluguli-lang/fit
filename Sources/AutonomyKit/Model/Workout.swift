import Foundation

/// Rate of Perceived Exertion, 5–10 in half steps. Optional everywhere —
/// prescribing RPE is a tool, not a requirement.
public struct RPE: Codable, Hashable, Comparable, Sendable {
    public let value: Double

    public init?(_ value: Double) {
        guard value >= 5, value <= 10 else { return nil }
        self.value = (value * 2).rounded() / 2
    }

    public static func < (lhs: RPE, rhs: RPE) -> Bool { lhs.value < rhs.value }
}

/// One prescribed set. Every field is optional except the exercise it belongs
/// to, so a plan can be as loose as "squat, 3 hard sets".
public struct PrescribedSet: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var reps: Int?
    public var repRangeUpper: Int?
    public var weightKg: Double?
    public var seconds: Int?
    public var distanceMeters: Double?
    public var rpe: RPE?
    public var restSeconds: Int?

    public init(
        id: UUID = UUID(),
        reps: Int? = nil,
        repRangeUpper: Int? = nil,
        weightKg: Double? = nil,
        seconds: Int? = nil,
        distanceMeters: Double? = nil,
        rpe: RPE? = nil,
        restSeconds: Int? = nil
    ) {
        self.id = id
        self.reps = reps
        self.repRangeUpper = repRangeUpper
        self.weightKg = weightKg
        self.seconds = seconds
        self.distanceMeters = distanceMeters
        self.rpe = rpe
        self.restSeconds = restSeconds
    }
}

public struct PlannedExercise: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var exerciseID: UUID
    public var sets: [PrescribedSet]
    public var note: String

    public init(id: UUID = UUID(), exerciseID: UUID, sets: [PrescribedSet] = [], note: String = "") {
        self.id = id
        self.exerciseID = exerciseID
        self.sets = sets
        self.note = note
    }
}

/// How a group of exercises is performed together.
public enum BlockStyle: String, Codable, Sendable {
    case straight
    case superset
    case circuit
}

public struct WorkoutBlock: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var style: BlockStyle
    public var exercises: [PlannedExercise]
    /// For circuits: how many times through.
    public var rounds: Int?
    public var restBetweenRoundsSeconds: Int?

    public init(
        id: UUID = UUID(),
        title: String = "",
        style: BlockStyle = .straight,
        exercises: [PlannedExercise] = [],
        rounds: Int? = nil,
        restBetweenRoundsSeconds: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.style = style
        self.exercises = exercises
        self.rounds = rounds
        self.restBetweenRoundsSeconds = restBetweenRoundsSeconds
    }
}

public struct WorkoutPlan: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var style: TrainingStyle
    public var blocks: [WorkoutBlock]
    public var estimatedMinutes: Int?
    /// True when the owner wrote or meaningfully edited this plan rather than
    /// running a shipped template unchanged.
    public var isUserCreated: Bool
    /// Set when the plan started life as a template and was then edited.
    public var derivedFromTemplateID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        style: TrainingStyle = .hybrid,
        blocks: [WorkoutBlock] = [],
        estimatedMinutes: Int? = nil,
        isUserCreated: Bool = true,
        derivedFromTemplateID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.style = style
        self.blocks = blocks
        self.estimatedMinutes = estimatedMinutes
        self.isUserCreated = isUserCreated
        self.derivedFromTemplateID = derivedFromTemplateID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notes = notes
    }

    public var plannedExercises: [PlannedExercise] {
        blocks.flatMap(\.exercises)
    }
}
