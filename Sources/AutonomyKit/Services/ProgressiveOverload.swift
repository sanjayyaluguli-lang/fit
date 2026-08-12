import Foundation

/// One exercise's showing on one day, reduced to the numbers worth trending.
public struct ExercisePerformance: Hashable, Sendable {
    public let date: Date
    public let bestWeightKg: Double?
    public let bestReps: Int?
    public let estimatedOneRepMaxKg: Double?
    public let workingVolumeKg: Double
    public let topSetRPE: RPE?
}

public struct OverloadSuggestion: Hashable, Sendable {
    public let exerciseID: UUID
    public let suggestedWeightKg: Double?
    public let suggestedReps: Int?
    public let rationale: String
    /// The app suggests; it never prescribes. The UI presents this as one
    /// option next to "do your own thing", and taking your own line counts
    /// toward the Independence Score.
    public let isOptional: Bool = true
}

public enum ProgressiveOverload {

    /// Epley. Chosen over Brzycki because it stays sane past ~10 reps, which is
    /// where a lot of real training actually happens.
    public static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, reps > 0 else { return nil }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }

    /// Per-day performance for one exercise, oldest first.
    public static func history(
        for exerciseID: UUID,
        in sessions: [WorkoutSession]
    ) -> [ExercisePerformance] {
        sessions
            .compactMap { session -> ExercisePerformance? in
                let sets = session.workingSets.filter { $0.exerciseID == exerciseID }
                guard !sets.isEmpty else { return nil }

                let scored = sets.compactMap { set -> (SetLog, Double)? in
                    guard let weight = set.weightKg, let reps = set.reps,
                          let e1rm = estimatedOneRepMax(weightKg: weight, reps: reps)
                    else { return nil }
                    return (set, e1rm)
                }
                let best = scored.max { $0.1 < $1.1 }

                return ExercisePerformance(
                    date: session.date,
                    bestWeightKg: best?.0.weightKg,
                    bestReps: best?.0.reps,
                    estimatedOneRepMaxKg: best?.1,
                    workingVolumeKg: sets.compactMap(\.volumeKg).reduce(0, +),
                    topSetRPE: best?.0.rpe
                )
            }
            .sorted { $0.date < $1.date }
    }

    /// Best estimated 1RM ever recorded, per exercise.
    public static func personalRecords(in sessions: [WorkoutSession]) -> [PersonalRecord] {
        var bestByExercise: [UUID: PersonalRecord] = [:]

        for session in sessions {
            for set in session.workingSets {
                guard let weight = set.weightKg, let reps = set.reps,
                      let e1rm = estimatedOneRepMax(weightKg: weight, reps: reps)
                else { continue }

                let candidate = PersonalRecord(
                    exerciseID: set.exerciseID,
                    date: session.date,
                    weightKg: weight,
                    reps: reps,
                    estimatedOneRepMaxKg: e1rm
                )
                if let existing = bestByExercise[set.exerciseID],
                   existing.estimatedOneRepMaxKg >= e1rm {
                    continue
                }
                bestByExercise[set.exerciseID] = candidate
            }
        }

        return bestByExercise.values.sorted { $0.date > $1.date }
    }

    /// Whether this session set a new record for any exercise, given everything
    /// logged before it.
    public static func newRecords(
        in session: WorkoutSession,
        priorSessions: [WorkoutSession]
    ) -> [PersonalRecord] {
        let prior = Dictionary(
            uniqueKeysWithValues: personalRecords(in: priorSessions).map { ($0.exerciseID, $0) }
        )
        return personalRecords(in: [session]).filter { record in
            guard let old = prior[record.exerciseID] else { return true }
            return record.estimatedOneRepMaxKg > old.estimatedOneRepMaxKg
        }
    }

    /// A single, low-key suggestion for next time. Returns nil when there isn't
    /// enough history to say anything useful — silence beats invented advice.
    public static func suggestion(
        for exerciseID: UUID,
        in sessions: [WorkoutSession],
        smallestIncrementKg: Double = 2.5
    ) -> OverloadSuggestion? {
        let performances = history(for: exerciseID, in: sessions)
        guard let last = performances.last,
              let weight = last.bestWeightKg,
              let reps = last.bestReps
        else { return nil }

        // Left it in the tank: add the smallest plate jump available.
        if let rpe = last.topSetRPE, rpe.value <= 7 {
            let next = roundToIncrement(weight + smallestIncrementKg, increment: smallestIncrementKg)
            return OverloadSuggestion(
                exerciseID: exerciseID,
                suggestedWeightKg: next,
                suggestedReps: reps,
                rationale: "Last top set went at RPE \(formatted(rpe.value)). \(formatted(next)) kg for \(reps) is a fair next step."
            )
        }

        // Genuinely hard last time: hold the load and add a rep instead.
        if let rpe = last.topSetRPE, rpe.value >= 9.5 {
            return OverloadSuggestion(
                exerciseID: exerciseID,
                suggestedWeightKg: weight,
                suggestedReps: reps,
                rationale: "That was near your limit. Same weight, same reps — let it get easier before it gets heavier."
            )
        }

        // No RPE recorded: fall back to the trend of the last three sessions.
        let recent = performances.suffix(3).compactMap(\.estimatedOneRepMaxKg)
        if recent.count >= 2, let first = recent.first, let latest = recent.last, latest <= first {
            return OverloadSuggestion(
                exerciseID: exerciseID,
                suggestedWeightKg: weight,
                suggestedReps: reps + 1,
                rationale: "Strength has been flat here. Try one more rep at \(formatted(weight)) kg before adding load."
            )
        }

        let next = roundToIncrement(weight + smallestIncrementKg, increment: smallestIncrementKg)
        return OverloadSuggestion(
            exerciseID: exerciseID,
            suggestedWeightKg: next,
            suggestedReps: reps,
            rationale: "Moving in the right direction. \(formatted(next)) kg for \(reps) if it feels right on the day."
        )
    }

    private static func roundToIncrement(_ value: Double, increment: Double) -> Double {
        guard increment > 0 else { return value }
        return (value / increment).rounded() * increment
    }

    private static func formatted(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
