import Foundation

public enum BodyMetricKind: String, Codable, CaseIterable, Sendable {
    case weightKg
    case waistCm
    case hipCm
    case chestCm
    case armCm
    case thighCm
    case bodyFatPercent

    public var displayName: String {
        switch self {
        case .weightKg: return "Weight"
        case .waistCm: return "Waist"
        case .hipCm: return "Hip"
        case .chestCm: return "Chest"
        case .armCm: return "Arm"
        case .thighCm: return "Thigh"
        case .bodyFatPercent: return "Body fat"
        }
    }

    public var unit: String {
        switch self {
        case .weightKg: return "kg"
        case .bodyFatPercent: return "%"
        default: return "cm"
        }
    }
}

public struct BodyMetric: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var kind: BodyMetricKind
    public var value: Double
    /// True when the value arrived from HealthKit rather than manual entry, so
    /// two-way sync never writes it back and creates a loop.
    public var importedFromHealth: Bool

    public init(
        id: UUID = UUID(),
        date: Date,
        kind: BodyMetricKind,
        value: Double,
        importedFromHealth: Bool = false
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.value = value
        self.importedFromHealth = importedFromHealth
    }
}

/// Progress photos stay in the app's own encrypted-at-rest directory and are
/// referenced by file name only. They are excluded from any sync the owner
/// hasn't explicitly turned on.
public struct ProgressPhoto: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var fileName: String
    public var pose: String
    public var note: String

    public init(
        id: UUID = UUID(),
        date: Date,
        fileName: String,
        pose: String = "front",
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.fileName = fileName
        self.pose = pose
        self.note = note
    }
}

/// A best-ever effort on one exercise. Estimated 1RM is stored alongside the
/// real set so a 5-rep PR isn't hidden by an old heavy single.
public struct PersonalRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var exerciseID: UUID
    public var date: Date
    public var weightKg: Double
    public var reps: Int
    public var estimatedOneRepMaxKg: Double

    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        date: Date,
        weightKg: Double,
        reps: Int,
        estimatedOneRepMaxKg: Double
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.date = date
        self.weightKg = weightKg
        self.reps = reps
        self.estimatedOneRepMaxKg = estimatedOneRepMaxKg
    }
}
