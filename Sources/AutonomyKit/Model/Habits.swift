import Foundation

/// Habits are first-class: they get the same storage, streaks and trend views
/// as training. Most of what makes a year work lives here.
public enum HabitKind: String, Codable, CaseIterable, Sendable {
    case protein
    case steps
    case bedtime
    case stress
    case mobility
    case custom

    public var defaultTitle: String {
        switch self {
        case .protein: return "Protein at every meal"
        case .steps: return "Daily steps"
        case .bedtime: return "Bedtime window"
        case .stress: return "Stress reset"
        case .mobility: return "Mobility minutes"
        case .custom: return "Custom habit"
        }
    }
}

public struct Habit: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: HabitKind
    public var title: String
    /// Numeric goal where one makes sense (steps, minutes, grams). Nil means
    /// the habit is simply done or not.
    public var target: Double?
    public var unit: String?
    public var isActive: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: HabitKind,
        title: String? = nil,
        target: Double? = nil,
        unit: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title ?? kind.defaultTitle
        self.target = target
        self.unit = unit
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

public struct HabitLog: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var habitID: UUID
    public var date: Date
    public var completed: Bool
    public var value: Double?
    public var note: String

    public init(
        id: UUID = UUID(),
        habitID: UUID,
        date: Date,
        completed: Bool,
        value: Double? = nil,
        note: String = ""
    ) {
        self.id = id
        self.habitID = habitID
        self.date = date
        self.completed = completed
        self.value = value
        self.note = note
    }
}
