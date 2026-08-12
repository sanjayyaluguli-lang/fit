import Foundation

public enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest, back, shoulders, quads, hamstrings, glutes, calves
    case biceps, triceps, core, fullBody, cardio
}

public enum LoadType: String, Codable, Sendable {
    /// Barbell, dumbbell, machine — logged as weight x reps.
    case external
    /// Push-ups, pull-ups — logged as reps, optional added weight.
    case bodyweight
    /// Plank, dead hang, carries — logged as seconds.
    case duration
    /// Runs, rows, bike — logged as distance and/or duration.
    case distance
}

public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var primaryMuscles: [MuscleGroup]
    public var loadType: LoadType
    /// Owner-authored exercises are marked so the Independence Score can see
    /// that the library is becoming theirs rather than the app's.
    public var isUserCreated: Bool
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        primaryMuscles: [MuscleGroup] = [],
        loadType: LoadType = .external,
        isUserCreated: Bool = true,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.primaryMuscles = primaryMuscles
        self.loadType = loadType
        self.isUserCreated = isUserCreated
        self.notes = notes
    }
}

public enum ExerciseCatalog {
    /// A deliberately short seed list. The app does not ship a 1,200-exercise
    /// database — the owner adds what they actually do, which is also what the
    /// Independence Score rewards.
    public static func seed() -> [Exercise] {
        [
            Exercise(name: "Back Squat", primaryMuscles: [.quads, .glutes], loadType: .external, isUserCreated: false),
            Exercise(name: "Deadlift", primaryMuscles: [.hamstrings, .back, .glutes], loadType: .external, isUserCreated: false),
            Exercise(name: "Bench Press", primaryMuscles: [.chest, .triceps], loadType: .external, isUserCreated: false),
            Exercise(name: "Overhead Press", primaryMuscles: [.shoulders, .triceps], loadType: .external, isUserCreated: false),
            Exercise(name: "Barbell Row", primaryMuscles: [.back, .biceps], loadType: .external, isUserCreated: false),
            Exercise(name: "Pull-Up", primaryMuscles: [.back, .biceps], loadType: .bodyweight, isUserCreated: false),
            Exercise(name: "Push-Up", primaryMuscles: [.chest, .triceps], loadType: .bodyweight, isUserCreated: false),
            Exercise(name: "Romanian Deadlift", primaryMuscles: [.hamstrings, .glutes], loadType: .external, isUserCreated: false),
            Exercise(name: "Split Squat", primaryMuscles: [.quads, .glutes], loadType: .external, isUserCreated: false),
            Exercise(name: "Plank", primaryMuscles: [.core], loadType: .duration, isUserCreated: false),
            Exercise(name: "Farmer Carry", primaryMuscles: [.core, .fullBody], loadType: .duration, isUserCreated: false),
            Exercise(name: "Zone 2 Run", primaryMuscles: [.cardio], loadType: .distance, isUserCreated: false),
            Exercise(name: "Rower Intervals", primaryMuscles: [.cardio, .fullBody], loadType: .distance, isUserCreated: false)
        ]
    }
}
