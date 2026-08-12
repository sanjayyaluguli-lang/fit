import Foundation

/// A day of Apple Health / HealthKit numbers, already reduced to daily values.
/// Every field is optional — a day with only step count is still a usable day.
public struct HealthDaily: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var steps: Int?
    public var activeEnergyKcal: Double?
    public var restingHeartRate: Double?
    public var hrvSDNN: Double?
    public var respiratoryRate: Double?
    public var bloodOxygenPercent: Double?
    public var sleepMinutes: Int?
    public var deepSleepMinutes: Int?
    public var remSleepMinutes: Int?
    public var weightKg: Double?

    public init(
        id: UUID = UUID(),
        date: Date,
        steps: Int? = nil,
        activeEnergyKcal: Double? = nil,
        restingHeartRate: Double? = nil,
        hrvSDNN: Double? = nil,
        respiratoryRate: Double? = nil,
        bloodOxygenPercent: Double? = nil,
        sleepMinutes: Int? = nil,
        deepSleepMinutes: Int? = nil,
        remSleepMinutes: Int? = nil,
        weightKg: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.restingHeartRate = restingHeartRate
        self.hrvSDNN = hrvSDNN
        self.respiratoryRate = respiratoryRate
        self.bloodOxygenPercent = bloodOxygenPercent
        self.sleepMinutes = sleepMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.weightKg = weightKg
    }
}

/// Whoop's view of a day. Kept separate from HealthDaily so a future Garmin or
/// Oura provider can fill the same shape without pretending to be Apple Health.
public struct RecoverySnapshot: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var provider: ConnectedTool
    /// 0–100.
    public var recoveryScore: Double?
    /// Whoop strain, 0–21.
    public var strain: Double?
    /// 0–100.
    public var sleepPerformance: Double?
    public var hrvMilliseconds: Double?
    public var restingHeartRate: Double?
    public var respiratoryRate: Double?

    public init(
        id: UUID = UUID(),
        date: Date,
        provider: ConnectedTool = .whoop,
        recoveryScore: Double? = nil,
        strain: Double? = nil,
        sleepPerformance: Double? = nil,
        hrvMilliseconds: Double? = nil,
        restingHeartRate: Double? = nil,
        respiratoryRate: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.provider = provider
        self.recoveryScore = recoveryScore
        self.strain = strain
        self.sleepPerformance = sleepPerformance
        self.hrvMilliseconds = hrvMilliseconds
        self.restingHeartRate = restingHeartRate
        self.respiratoryRate = respiratoryRate
    }
}

/// The owner's own read on the day. Weighted alongside the wearables rather
/// than beneath them — the whole point is to keep the person in the loop.
public struct SubjectiveCheckIn: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    /// 1–5.
    public var energy: Int
    /// 1–5, higher means more stressed.
    public var stress: Int?
    public var soreness: Int?
    public var note: String

    public init(
        id: UUID = UUID(),
        date: Date,
        energy: Int,
        stress: Int? = nil,
        soreness: Int? = nil,
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.energy = energy
        self.stress = stress
        self.soreness = soreness
        self.note = note
    }
}
