import Foundation

/// The weekly review is the app's main teaching surface. It asks about
/// sustainability first and shows numbers second, on purpose.
public struct ReflectionPrompt: Identifiable, Hashable, Sendable {
    public let id: String
    public let question: String
    public let hint: String

    public init(id: String, question: String, hint: String = "") {
        self.id = id
        self.question = question
        self.hint = hint
    }

    public static let standard: [ReflectionPrompt] = [
        ReflectionPrompt(
            id: "energy",
            question: "How was your energy across the week?",
            hint: "Compared to a normal week for you, not to your best week ever."
        ),
        ReflectionPrompt(
            id: "sustainable",
            question: "What part of this week could you repeat for a year?",
            hint: "Keep that. It's the actual plan."
        ),
        ReflectionPrompt(
            id: "friction",
            question: "What felt like effort you'd rather not repeat?",
            hint: "Anything you had to force is a candidate for cutting."
        ),
        ReflectionPrompt(
            id: "adjust",
            question: "What would you change yourself next week?",
            hint: "Your call, not the app's."
        )
    ]
}

public struct WeeklyReview: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// The Monday (or locale first weekday) that starts the reviewed week.
    public var weekStart: Date
    /// Prompt id -> the owner's answer.
    public var answers: [String: String]
    /// 1–5. How doable the week felt, which matters more than whether it was
    /// completed as written.
    public var sustainabilityRating: Int?
    /// Changes the owner decided on themselves. Counted by the Independence
    /// Score.
    public var selfDirectedAdjustments: [String]
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        weekStart: Date,
        answers: [String: String] = [:],
        sustainabilityRating: Int? = nil,
        selfDirectedAdjustments: [String] = [],
        completedAt: Date? = nil
    ) {
        self.id = id
        self.weekStart = weekStart
        self.answers = answers
        self.sustainabilityRating = sustainabilityRating
        self.selfDirectedAdjustments = selfDirectedAdjustments
        self.completedAt = completedAt
    }

    public var isComplete: Bool { completedAt != nil }
}
