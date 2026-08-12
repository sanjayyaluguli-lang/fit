import Foundation

public struct Insight: Hashable, Sendable, Identifiable {
    public enum Tone: String, Sendable {
        /// Something worth noticing and repeating.
        case affirming
        /// A neutral observation the owner may want to act on.
        case observation
        /// A gentle flag. Never urgent, never guilt.
        case caution
    }

    public var id: String
    public let title: String
    public let body: String
    public let tone: Tone
    /// Higher wins when the home screen only has room for one.
    public let priority: Int
}

/// Produces the single line the home screen shows. One insight, chosen from a
/// handful of candidates — a wall of "insights" is just a dashboard with
/// opinions, and it stops being read by week three.
public enum InsightEngine {

    public static func candidates(
        from data: AutonomyData,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> [Insight] {
        var insights: [Insight] = []

        // Consistency, framed as weeks rather than an unbroken streak.
        let consistency = Trends.weeksTrained(sessions: data.sessions, asOf: date, weeks: 12, calendar: calendar)
        if consistency.trained >= 9 {
            insights.append(
                Insight(
                    id: "consistency",
                    title: "\(consistency.trained) of the last 12 weeks",
                    body: "You've trained in \(consistency.trained) of the last 12 weeks. That's the whole game — nothing here needs changing.",
                    tone: .affirming,
                    priority: 60
                )
            )
        } else if consistency.trained >= 1 && consistency.trained <= 4 {
            insights.append(
                Insight(
                    id: "consistency-low",
                    title: "Quiet stretch",
                    body: "\(consistency.trained) of the last 12 weeks had a session. Pick the smallest one you'd actually do this week.",
                    tone: .observation,
                    priority: 55
                )
            )
        }

        // Sleep debt against the owner's own baseline.
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: date) ?? date
        let recent = data.healthDays
            .filter { $0.date <= date && $0.date > weekAgo }
            .compactMap(\.sleepMinutes)
        if recent.count >= 4 {
            let average = Double(recent.reduce(0, +)) / Double(recent.count)
            if average < 390 {
                insights.append(
                    Insight(
                        id: "sleep",
                        title: "Sleep is the limiter",
                        body: String(format: "You've averaged %.1f h over the last week. Training around that is fine; expecting PRs on it isn't.", average / 60),
                        tone: .caution,
                        priority: 80
                    )
                )
            }
        }

        // Strength moving on the lifts that are actually being trained.
        let records = ProgressiveOverload.personalRecords(in: data.sessions)
        if let newest = records.first,
           let days = calendar.dateComponents([.day], from: newest.date, to: date).day,
           days <= 14,
           let name = data.exercise(newest.exerciseID)?.name {
            insights.append(
                Insight(
                    id: "pr",
                    title: "New best on \(name)",
                    body: "\(format(newest.weightKg)) kg × \(newest.reps) is your best estimated max on \(name). Banked.",
                    tone: .affirming,
                    priority: 70
                )
            )
        }

        // Autonomy nudge, phrased as an invitation.
        let independence = data.independence(asOf: date)
        if independence.stage == .learning, data.sessions.count >= 6 {
            insights.append(
                Insight(
                    id: "independence",
                    title: independence.stage.headline,
                    body: independence.summary,
                    tone: .observation,
                    priority: 50
                )
            )
        }

        // A weekly review that's due.
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
           let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart),
           !data.reviews.contains(where: { calendar.isDate($0.weekStart, inSameDayAs: lastWeek) && $0.isComplete }),
           !data.sessions.isEmpty {
            insights.append(
                Insight(
                    id: "review",
                    title: "Last week is unreviewed",
                    body: "Four questions, five minutes. It's where you decide what to keep.",
                    tone: .observation,
                    priority: 40
                )
            )
        }

        return insights.sorted { $0.priority > $1.priority }
    }

    /// The one insight for the home screen, or nil when there's genuinely
    /// nothing worth saying. Saying nothing is a valid outcome.
    public static func headline(
        from data: AutonomyData,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> Insight? {
        candidates(from: data, asOf: date, calendar: calendar).first
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
