import Foundation

/// Where a completed session came from. Logging is uniform regardless — the
/// point is that a YouTube session and a barbell session land in the same
/// history with the same weight.
public enum SessionSource: Codable, Hashable, Sendable {
    case plan(UUID)
    case youtube(String)          // video ID
    case appleFitness
    case freeform
}

public struct SetLog: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var exerciseID: UUID
    public var setIndex: Int
    public var reps: Int?
    public var weightKg: Double?
    public var seconds: Int?
    public var distanceMeters: Double?
    public var rpe: RPE?
    public var isWarmup: Bool

    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        setIndex: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        seconds: Int? = nil,
        distanceMeters: Double? = nil,
        rpe: RPE? = nil,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.setIndex = setIndex
        self.reps = reps
        self.weightKg = weightKg
        self.seconds = seconds
        self.distanceMeters = distanceMeters
        self.rpe = rpe
        self.isWarmup = isWarmup
    }

    /// Tonnage for this set. Bodyweight and duration work returns nil rather
    /// than guessing a load.
    public var volumeKg: Double? {
        guard let weightKg, let reps, !isWarmup else { return nil }
        return weightKg * Double(reps)
    }
}

/// How the session actually felt, in the owner's words and one coarse number.
/// Deliberately not a 1–100 "quality score".
public enum SessionFeel: String, Codable, CaseIterable, Sendable {
    case strong
    case solid
    case flat

    public var displayName: String {
        switch self {
        case .strong: return "Strong"
        case .solid: return "Solid"
        case .flat: return "Flat"
        }
    }
}

public struct WorkoutSession: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var source: SessionSource
    public var title: String
    public var style: TrainingStyle
    public var durationMinutes: Int?
    public var sets: [SetLog]
    public var feel: SessionFeel?
    /// 1–5, only ever used for rating a YouTube session so the owner can find
    /// the good ones again.
    public var rating: Int?
    public var notes: String
    /// True when the owner changed the plan on the day — swapped an exercise,
    /// cut a block, added one. This is the single strongest autonomy signal
    /// the app has, so it is recorded explicitly.
    public var deviatedFromPlan: Bool
    /// Set if the session was logged after the fact rather than live.
    public var loggedRetroactively: Bool

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        source: SessionSource = .freeform,
        title: String = "",
        style: TrainingStyle = .hybrid,
        durationMinutes: Int? = nil,
        sets: [SetLog] = [],
        feel: SessionFeel? = nil,
        rating: Int? = nil,
        notes: String = "",
        deviatedFromPlan: Bool = false,
        loggedRetroactively: Bool = false
    ) {
        self.id = id
        self.date = date
        self.source = source
        self.title = title
        self.style = style
        self.durationMinutes = durationMinutes
        self.sets = sets
        self.feel = feel
        self.rating = rating
        self.notes = notes
        self.deviatedFromPlan = deviatedFromPlan
        self.loggedRetroactively = loggedRetroactively
    }

    public var workingSets: [SetLog] { sets.filter { !$0.isWarmup } }

    public var totalVolumeKg: Double {
        sets.compactMap(\.volumeKg).reduce(0, +)
    }
}
