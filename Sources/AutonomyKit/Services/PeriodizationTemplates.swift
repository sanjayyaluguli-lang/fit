import Foundation

/// A small set of starting points, all of them meant to be edited. Every
/// template a plan is generated from is marked `isUserCreated == false` until
/// the owner changes something — that's how the Independence Score can tell the
/// difference between following and deciding.
public enum PeriodizationTemplates {

    public struct Template: Identifiable, Sendable {
        public let id: UUID
        public let name: String
        public let style: TrainingStyle
        public let summary: String
        public let daysPerWeek: Int
        /// Builds concrete plans against the owner's exercise library. Exercises
        /// that aren't in the library are skipped rather than invented.
        public let build: @Sendable ([Exercise]) -> [WorkoutPlan]
    }

    public static func all() -> [Template] {
        [minimalStrength(), upperLower(), hybridThree()]
    }

    // MARK: - Templates

    /// Two sessions, six lifts, indefinitely repeatable. The one that survives
    /// travel and a newborn.
    public static func minimalStrength() -> Template {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        return Template(
            id: id,
            name: "Minimal Strength",
            style: .strength,
            summary: "Two full-body days. Add a little when it feels easy, hold when it doesn't.",
            daysPerWeek: 2,
            build: { library in
                [
                    plan(
                        named: "Full Body A",
                        style: .strength,
                        templateID: id,
                        entries: [("Back Squat", 3, 5), ("Bench Press", 3, 5), ("Barbell Row", 3, 8)],
                        library: library
                    ),
                    plan(
                        named: "Full Body B",
                        style: .strength,
                        templateID: id,
                        entries: [("Deadlift", 2, 5), ("Overhead Press", 3, 6), ("Pull-Up", 3, 6)],
                        library: library
                    )
                ].compactMap { $0 }
            }
        )
    }

    public static func upperLower() -> Template {
        let id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        return Template(
            id: id,
            name: "Upper / Lower",
            style: .hypertrophy,
            summary: "Four days when life allows it, two when it doesn't. Same plans either way.",
            daysPerWeek: 4,
            build: { library in
                [
                    plan(
                        named: "Lower",
                        style: .hypertrophy,
                        templateID: id,
                        entries: [("Back Squat", 4, 8), ("Romanian Deadlift", 3, 10), ("Split Squat", 3, 10)],
                        library: library
                    ),
                    plan(
                        named: "Upper",
                        style: .hypertrophy,
                        templateID: id,
                        entries: [("Bench Press", 4, 8), ("Barbell Row", 4, 10), ("Overhead Press", 3, 10)],
                        library: library
                    )
                ].compactMap { $0 }
            }
        )
    }

    /// Strength plus conditioning, with the third day deliberately left open
    /// for whatever the owner feels like — including a YouTube session.
    public static func hybridThree() -> Template {
        let id = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        return Template(
            id: id,
            name: "Hybrid Three",
            style: .hybrid,
            summary: "Two lifting days, one open day. The open day is the point.",
            daysPerWeek: 3,
            build: { library in
                [
                    plan(
                        named: "Lift A",
                        style: .strength,
                        templateID: id,
                        entries: [("Back Squat", 3, 6), ("Bench Press", 3, 6), ("Farmer Carry", 3, 0)],
                        library: library
                    ),
                    plan(
                        named: "Lift B",
                        style: .strength,
                        templateID: id,
                        entries: [("Deadlift", 3, 5), ("Pull-Up", 3, 8), ("Plank", 3, 0)],
                        library: library
                    ),
                    plan(
                        named: "Open Day",
                        style: .conditioning,
                        templateID: id,
                        entries: [("Zone 2 Run", 1, 0)],
                        library: library
                    )
                ].compactMap { $0 }
            }
        )
    }

    // MARK: - Building

    private static func plan(
        named name: String,
        style: TrainingStyle,
        templateID: UUID,
        entries: [(String, Int, Int)],
        library: [Exercise]
    ) -> WorkoutPlan? {
        let planned: [PlannedExercise] = entries.compactMap { entry in
            let (exerciseName, setCount, reps) = entry
            guard let exercise = library.first(where: { $0.name.caseInsensitiveCompare(exerciseName) == .orderedSame })
            else { return nil }

            let sets = (0..<max(setCount, 1)).map { _ in
                PrescribedSet(reps: reps > 0 ? reps : nil, rpe: RPE(8), restSeconds: 120)
            }
            return PlannedExercise(exerciseID: exercise.id, sets: sets)
        }
        guard !planned.isEmpty else { return nil }

        return WorkoutPlan(
            name: name,
            style: style,
            blocks: [WorkoutBlock(title: name, style: .straight, exercises: planned)],
            isUserCreated: false,
            derivedFromTemplateID: templateID
        )
    }
}

public extension WorkoutPlan {
    /// Call whenever the owner edits a template-derived plan. From that moment
    /// on the plan is theirs.
    mutating func markEdited(now: Date = Date()) {
        isUserCreated = true
        updatedAt = now
    }
}
