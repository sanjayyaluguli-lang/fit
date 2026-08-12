import Foundation
import AutonomyKit
#if canImport(HealthKit)
import HealthKit
#endif

/// Apple Health, behind the `HealthDataProvider` seam.
///
/// Read: steps, active energy, resting HR, HRV, respiratory rate, SpO2, sleep
/// stages, body mass. Write: sessions logged in this app, so the rings and the
/// health record agree.
struct HealthKitProvider: HealthDataProvider {
    let tool: ConnectedTool = .appleHealth

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.workoutType()
        ]
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!]
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    func dailyMetrics(from start: Date, to end: Date) async throws -> [HealthDaily] {
        guard isAvailable else { return [] }
        let calendar = Calendar.current
        var byDay: [Date: HealthDaily] = [:]

        func record(_ day: Date, _ mutate: (inout HealthDaily) -> Void) {
            let key = calendar.startOfDay(for: day)
            var entry = byDay[key] ?? HealthDaily(date: key)
            mutate(&entry)
            byDay[key] = entry
        }

        let sums: [(HKQuantityTypeIdentifier, HKUnit, (inout HealthDaily, Double) -> Void)] = [
            (.stepCount, .count(), { $0.steps = Int($1) }),
            (.activeEnergyBurned, .kilocalorie(), { $0.activeEnergyKcal = $1 })
        ]
        for (identifier, unit, assign) in sums {
            for (day, value) in try await dailyStatistics(identifier, unit: unit, options: .cumulativeSum, from: start, to: end) {
                record(day) { assign(&$0, value) }
            }
        }

        let averages: [(HKQuantityTypeIdentifier, HKUnit, (inout HealthDaily, Double) -> Void)] = [
            (.restingHeartRate, HKUnit.count().unitDivided(by: .minute()), { $0.restingHeartRate = $1 }),
            (.heartRateVariabilitySDNN, .secondUnit(with: .milli), { $0.hrvSDNN = $1 }),
            (.respiratoryRate, HKUnit.count().unitDivided(by: .minute()), { $0.respiratoryRate = $1 }),
            (.oxygenSaturation, .percent(), { $0.bloodOxygenPercent = $1 * 100 }),
            (.bodyMass, .gramUnit(with: .kilo), { $0.weightKg = $1 })
        ]
        for (identifier, unit, assign) in averages {
            for (day, value) in try await dailyStatistics(identifier, unit: unit, options: .discreteAverage, from: start, to: end) {
                record(day) { assign(&$0, value) }
            }
        }

        for (day, sleep) in try await sleepMinutes(from: start, to: end) {
            record(day) {
                $0.sleepMinutes = sleep.asleep
                $0.deepSleepMinutes = sleep.deep
                $0.remSleepMinutes = sleep.rem
            }
        }

        return byDay.values.sorted { $0.date < $1.date }
    }

    func importedSessions(from start: Date, to end: Date) async throws -> [WorkoutSession] {
        guard isAvailable else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: (samples as? [HKWorkout]) ?? []) }
            }
            store.execute(query)
        }

        // Sessions this app wrote come back through the same query; skip them so
        // a round trip can't duplicate history.
        return workouts
            .filter { $0.sourceRevision.source.bundleIdentifier != Bundle.main.bundleIdentifier }
            .map { workout in
                WorkoutSession(
                    id: workout.uuid,
                    date: workout.startDate,
                    source: .appleFitness,
                    title: workout.workoutActivityType.autonomyName,
                    style: workout.workoutActivityType.autonomyStyle,
                    durationMinutes: Int(workout.duration / 60),
                    loggedRetroactively: true
                )
            }
    }

    func export(session: WorkoutSession) async throws {
        guard isAvailable, let minutes = session.durationMinutes else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = session.style == .conditioning ? .mixedCardio : .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        let end = session.date.addingTimeInterval(TimeInterval(minutes * 60))
        try await builder.beginCollection(at: session.date)
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }

    // MARK: - Queries

    private func dailyStatistics(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        from start: Date,
        to end: Date
    ) async throws -> [(Date, Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        let anchor = Calendar.current.startOfDay(for: start)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                options: options,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, error in
                if let error { return continuation.resume(throwing: error) }
                var output: [(Date, Double)] = []
                results?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let quantity = options == .cumulativeSum ? statistics.sumQuantity() : statistics.averageQuantity()
                    if let quantity {
                        output.append((statistics.startDate, quantity.doubleValue(for: unit)))
                    }
                }
                continuation.resume(returning: output)
            }
            store.execute(query)
        }
    }

    private struct SleepTotals {
        var asleep: Int = 0
        var deep: Int = 0
        var rem: Int = 0
    }

    /// Sleep is attributed to the day you wake up on, which is how people
    /// actually talk about it.
    private func sleepMinutes(from start: Date, to end: Date) async throws -> [(Date, SleepTotals)] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: HKQuery.predicateForSamples(withStart: start, end: end),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: (samples as? [HKCategorySample]) ?? []) }
            }
            store.execute(query)
        }

        let calendar = Calendar.current
        var totals: [Date: SleepTotals] = [:]
        for sample in samples {
            let minutes = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
            let day = calendar.startOfDay(for: sample.endDate)
            var entry = totals[day] ?? SleepTotals()

            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepDeep:
                entry.deep += minutes
                entry.asleep += minutes
            case .asleepREM:
                entry.rem += minutes
                entry.asleep += minutes
            case .asleepCore, .asleepUnspecified:
                entry.asleep += minutes
            default:
                continue
            }
            totals[day] = entry
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
    #else
    var isAvailable: Bool { false }
    func requestAuthorization() async throws {}
    func dailyMetrics(from start: Date, to end: Date) async throws -> [HealthDaily] { [] }
    func importedSessions(from start: Date, to end: Date) async throws -> [WorkoutSession] { [] }
    #endif
}

#if canImport(HealthKit)
private extension HKWorkoutActivityType {
    var autonomyName: String {
        switch self {
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .running: return "Run"
        case .cycling: return "Ride"
        case .walking: return "Walk"
        case .rowing: return "Row"
        case .yoga, .flexibility: return "Mobility"
        case .highIntensityIntervalTraining: return "Intervals"
        default: return "Workout"
        }
    }

    var autonomyStyle: TrainingStyle {
        switch self {
        case .traditionalStrengthTraining, .functionalStrengthTraining: return .strength
        case .yoga, .flexibility: return .mobility
        case .running, .cycling, .rowing, .walking, .highIntensityIntervalTraining: return .conditioning
        default: return .hybrid
        }
    }
}
#endif
