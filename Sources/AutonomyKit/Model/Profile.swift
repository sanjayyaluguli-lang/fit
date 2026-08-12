import Foundation

/// How the owner wants to train. Not a program — a bias the app respects when it
/// suggests anything at all.
public enum TrainingStyle: String, Codable, CaseIterable, Sendable {
    case strength
    case hypertrophy
    case hybrid
    case conditioning
    case mobility

    public var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .hybrid: return "Hybrid"
        case .conditioning: return "Conditioning"
        case .mobility: return "Mobility"
        }
    }
}

public enum Goal: String, Codable, CaseIterable, Sendable {
    case fatLoss
    case recomposition
    case strength
    case maintainThroughLife

    public var displayName: String {
        switch self {
        case .fatLoss: return "Sustainable fat loss"
        case .recomposition: return "Recomposition"
        case .strength: return "Get stronger"
        case .maintainThroughLife: return "Hold what I have through a busy life"
        }
    }
}

/// Data sources the owner already uses. Nothing is required; the app degrades
/// gracefully down to manual entry.
public enum ConnectedTool: String, Codable, CaseIterable, Sendable {
    case appleHealth
    case appleWatch
    case whoop
    case garmin
    case oura
    case strava
    case none
}

/// Free-text constraints that shape suggestions: travel weeks, family meals,
/// cultural food patterns, prayer/fasting windows, shift work.
public struct LifestyleConstraint: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    public var note: String

    public init(id: UUID = UUID(), label: String, note: String = "") {
        self.id = id
        self.label = label
        self.note = note
    }
}

public struct UserProfile: Codable, Hashable, Sendable {
    public var displayName: String
    public var goals: [Goal]
    public var preferredStyles: [TrainingStyle]
    public var connectedTools: [ConnectedTool]
    public var constraints: [LifestyleConstraint]
    /// Sessions the owner realistically expects to hit in a week. Used for
    /// consistency framing, never for guilt copy.
    public var targetSessionsPerWeek: Int
    public var targetStepsPerDay: Int
    public var targetProteinGrams: Int?
    /// Reminders are off unless the owner turns them on.
    public var remindersEnabled: Bool
    public var createdAt: Date

    public init(
        displayName: String = "",
        goals: [Goal] = [],
        preferredStyles: [TrainingStyle] = [],
        connectedTools: [ConnectedTool] = [],
        constraints: [LifestyleConstraint] = [],
        targetSessionsPerWeek: Int = 3,
        targetStepsPerDay: Int = 8000,
        targetProteinGrams: Int? = nil,
        remindersEnabled: Bool = false,
        createdAt: Date = Date()
    ) {
        self.displayName = displayName
        self.goals = goals
        self.preferredStyles = preferredStyles
        self.connectedTools = connectedTools
        self.constraints = constraints
        self.targetSessionsPerWeek = targetSessionsPerWeek
        self.targetStepsPerDay = targetStepsPerDay
        self.targetProteinGrams = targetProteinGrams
        self.remindersEnabled = remindersEnabled
        self.createdAt = createdAt
    }
}
