import Foundation

/// The seam every wearable plugs into.
///
/// AutonomyKit knows nothing about HealthKit, Whoop, Garmin or Oura — it knows
/// these two protocols. Adding Oura later means writing one conformance in the
/// app target and adding it to the sync list; nothing in the domain changes.
public protocol HealthDataProvider: Sendable {
    var tool: ConnectedTool { get }
    var isAvailable: Bool { get }

    /// Daily aggregates for the range, ascending by date.
    func dailyMetrics(from start: Date, to end: Date) async throws -> [HealthDaily]

    /// Sessions recorded by the platform (Apple Fitness, Watch) that the app
    /// didn't log itself.
    func importedSessions(from start: Date, to end: Date) async throws -> [WorkoutSession]

    /// Two-way sync: push a session the owner logged here back out, so the
    /// rings and the health record stay honest. No-op for read-only providers.
    func export(session: WorkoutSession) async throws
}

public protocol RecoveryDataProvider: Sendable {
    var tool: ConnectedTool { get }
    var isAvailable: Bool { get }

    func recovery(from start: Date, to end: Date) async throws -> [RecoverySnapshot]
}

public extension HealthDataProvider {
    func export(session: WorkoutSession) async throws {}
}

/// Stand-in used in previews, tests and on any platform where the real
/// framework doesn't exist. Keeps the app fully usable with zero integrations.
public struct NullHealthProvider: HealthDataProvider {
    public let tool: ConnectedTool = .none
    public let isAvailable = false

    public init() {}

    public func dailyMetrics(from start: Date, to end: Date) async throws -> [HealthDaily] { [] }
    public func importedSessions(from start: Date, to end: Date) async throws -> [WorkoutSession] { [] }
}

/// Merges provider output into the store without ever clobbering owner-entered
/// data: imported rows are matched by day and only fill fields that are empty.
public enum SyncCoordinator {

    public static func merge(_ incoming: [HealthDaily], into existing: [HealthDaily], calendar: Calendar = .current) -> [HealthDaily] {
        var result = existing
        for day in incoming {
            if let index = result.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day.date) }) {
                result[index] = fill(result[index], with: day)
            } else {
                result.append(day)
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    public static func merge(_ incoming: [RecoverySnapshot], into existing: [RecoverySnapshot], calendar: Calendar = .current) -> [RecoverySnapshot] {
        var result = existing
        for snapshot in incoming {
            if let index = result.firstIndex(where: {
                calendar.isDate($0.date, inSameDayAs: snapshot.date) && $0.provider == snapshot.provider
            }) {
                // Recovery scores are revised through the morning; last write wins.
                var updated = snapshot
                updated.id = result[index].id
                result[index] = updated
            } else {
                result.append(snapshot)
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    private static func fill(_ base: HealthDaily, with incoming: HealthDaily) -> HealthDaily {
        var merged = base
        merged.steps = base.steps ?? incoming.steps
        merged.activeEnergyKcal = base.activeEnergyKcal ?? incoming.activeEnergyKcal
        merged.restingHeartRate = base.restingHeartRate ?? incoming.restingHeartRate
        merged.hrvSDNN = base.hrvSDNN ?? incoming.hrvSDNN
        merged.respiratoryRate = base.respiratoryRate ?? incoming.respiratoryRate
        merged.bloodOxygenPercent = base.bloodOxygenPercent ?? incoming.bloodOxygenPercent
        merged.sleepMinutes = base.sleepMinutes ?? incoming.sleepMinutes
        merged.deepSleepMinutes = base.deepSleepMinutes ?? incoming.deepSleepMinutes
        merged.remSleepMinutes = base.remSleepMinutes ?? incoming.remSleepMinutes
        merged.weightKg = base.weightKg ?? incoming.weightKg
        return merged
    }
}
