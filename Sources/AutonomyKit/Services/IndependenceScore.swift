import Foundation

public struct IndependenceComponent: Hashable, Sendable {
    public let label: String
    /// 0–100.
    public let score: Double
    public let weight: Double
    public let detail: String
}

/// Named stages rather than levels — there is no "final" one to grind toward,
/// and going backwards during a hard month is not a failure state.
public enum IndependenceStage: String, Sendable {
    case learning
    case adapting
    case selfDirected
    case independent

    public var headline: String {
        switch self {
        case .learning: return "Learning the ropes"
        case .adapting: return "Adapting as you go"
        case .selfDirected: return "Mostly self-directed"
        case .independent: return "You don't need this app"
        }
    }

    public var caption: String {
        switch self {
        case .learning:
            return "Using what's here is fine. Change one thing when it doesn't fit you."
        case .adapting:
            return "You're editing the plan to match your life. That's the skill."
        case .selfDirected:
            return "Most of what you train is yours now."
        case .independent:
            return "You're running your own training. Keep the app for the record, not the instructions."
        }
    }
}

public struct IndependenceReport: Sendable {
    public let score: Double
    public let stage: IndependenceStage
    public let components: [IndependenceComponent]
    public let summary: String
}

/// Rewards the owner for taking over: writing their own sessions, changing the
/// plan mid-week, building a library that reflects what they actually do, and
/// reviewing honestly. Explicitly does *not* reward streaks, obedience or
/// volume — an app that scores compliance produces dependence.
public enum IndependenceScore {

    public static func evaluate(
        sessions: [WorkoutSession],
        plans: [WorkoutPlan],
        exercises: [Exercise],
        reviews: [WeeklyReview],
        asOf: Date = Date(),
        windowDays: Int = 90,
        calendar: Calendar = .current
    ) -> IndependenceReport {
        let start = calendar.date(byAdding: .day, value: -windowDays, to: asOf) ?? asOf
        let windowSessions = sessions.filter { $0.date >= start && $0.date <= asOf }
        let windowReviews = reviews.filter { $0.weekStart >= start && $0.weekStart <= asOf }

        let userPlanIDs = Set(plans.filter(\.isUserCreated).map(\.id))
        var components: [IndependenceComponent] = []

        // 1. Whose sessions are these?
        let selfDirected = windowSessions.filter { session in
            switch session.source {
            case .freeform: return true
            case .plan(let id): return userPlanIDs.contains(id)
            case .youtube: return !session.notes.isEmpty || session.rating != nil
            case .appleFitness: return true
            }
        }
        if windowSessions.isEmpty {
            components.append(
                IndependenceComponent(
                    label: "Your sessions",
                    score: 0,
                    weight: 0.30,
                    detail: "nothing logged in this window"
                )
            )
        } else {
            let ratio = Double(selfDirected.count) / Double(windowSessions.count)
            components.append(
                IndependenceComponent(
                    label: "Your sessions",
                    score: ratio * 100,
                    weight: 0.30,
                    detail: "\(selfDirected.count) of \(windowSessions.count) were yours to shape"
                )
            )
        }

        // 2. Changing the plan on the day. Saturates at ~a third of sessions —
        //    deviating from everything is not the goal either.
        let deviations = windowSessions.filter(\.deviatedFromPlan).count
        let deviationRatio = windowSessions.isEmpty
            ? 0
            : Double(deviations) / Double(windowSessions.count)
        components.append(
            IndependenceComponent(
                label: "Adjusting as you go",
                score: min(deviationRatio / 0.35, 1) * 100,
                weight: 0.25,
                detail: deviations == 0
                    ? "no adjustments recorded"
                    : "\(deviations) session\(deviations == 1 ? "" : "s") changed on the day"
            )
        )

        // 3. A library that looks like your training, not the app's defaults.
        let ownedPlans = plans.filter(\.isUserCreated).count
        let ownedExercises = exercises.filter(\.isUserCreated).count
        let owned = ownedPlans + ownedExercises
        components.append(
            IndependenceComponent(
                label: "Built by you",
                score: min(Double(owned) / 8, 1) * 100,
                weight: 0.20,
                detail: "\(ownedPlans) plan\(ownedPlans == 1 ? "" : "s"), \(ownedExercises) exercise\(ownedExercises == 1 ? "" : "s")"
            )
        )

        // 4. Reviewing, and acting on your own conclusions.
        let expectedReviews = max(Double(windowDays) / 7, 1)
        let completed = windowReviews.filter(\.isComplete)
        let reviewRatio = min(Double(completed.count) / expectedReviews, 1)
        let withAdjustments = completed.filter { !$0.selfDirectedAdjustments.isEmpty }.count
        let adjustmentBoost = completed.isEmpty
            ? 0
            : Double(withAdjustments) / Double(completed.count) * 0.3
        components.append(
            IndependenceComponent(
                label: "Reviewing honestly",
                score: min(reviewRatio + adjustmentBoost, 1) * 100,
                weight: 0.25,
                detail: "\(completed.count) review\(completed.count == 1 ? "" : "s"), \(withAdjustments) with your own changes"
            )
        )

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let score = totalWeight > 0
            ? components.reduce(0) { $0 + $1.score * $1.weight } / totalWeight
            : 0

        let stage: IndependenceStage
        switch score {
        case ..<40: stage = .learning
        case ..<70: stage = .adapting
        case ..<90: stage = .selfDirected
        default: stage = .independent
        }

        return IndependenceReport(
            score: score,
            stage: stage,
            components: components.sorted { $0.weight > $1.weight },
            summary: summary(for: stage, components: components)
        )
    }

    private static func summary(for stage: IndependenceStage, components: [IndependenceComponent]) -> String {
        guard let weakest = components.min(by: { $0.score < $1.score }), weakest.score < 60 else {
            return stage.caption
        }
        switch weakest.label {
        case "Your sessions":
            return "Most of what you ran came from somewhere else. Write one session yourself this week — it doesn't have to be clever."
        case "Adjusting as you go":
            return "You've been running plans as written. If a session doesn't fit the day, change it and mark it — that's the point."
        case "Built by you":
            return "Add the lifts and sessions you actually do. The app's defaults aren't your training."
        default:
            return "The weekly review is where the learning sticks. Five minutes, four questions."
        }
    }
}
