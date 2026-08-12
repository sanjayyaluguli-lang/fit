import XCTest
@testable import AutonomyKit

final class ProgressiveOverloadTests: XCTestCase {

    private let squat = UUID()
    private let calendar = Calendar(identifier: .gregorian)
    private lazy var day0 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: day0)!
    }

    private func session(
        on offset: Int,
        weight: Double,
        reps: Int,
        rpe: Double? = nil,
        warmup: Bool = false
    ) -> WorkoutSession {
        WorkoutSession(
            date: day(offset),
            sets: [
                SetLog(
                    exerciseID: squat,
                    setIndex: 1,
                    reps: reps,
                    weightKg: weight,
                    rpe: rpe.flatMap(RPE.init),
                    isWarmup: warmup
                )
            ]
        )
    }

    func testEpleyEstimate() throws {
        XCTAssertEqual(try XCTUnwrap(ProgressiveOverload.estimatedOneRepMax(weightKg: 100, reps: 5)), 116.667, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(ProgressiveOverload.estimatedOneRepMax(weightKg: 140, reps: 1)), 140, accuracy: 0.001)
        XCTAssertNil(ProgressiveOverload.estimatedOneRepMax(weightKg: 0, reps: 5))
        XCTAssertNil(ProgressiveOverload.estimatedOneRepMax(weightKg: 100, reps: 0))
    }

    func testWarmupSetsAreExcludedFromVolumeAndRecords() {
        let logged = session(on: 0, weight: 60, reps: 10, warmup: true)

        XCTAssertEqual(logged.totalVolumeKg, 0)
        XCTAssertTrue(ProgressiveOverload.personalRecords(in: [logged]).isEmpty)
    }

    func testHistoryIsOrderedAndKeepsTheBestSet() throws {
        var heavy = session(on: 2, weight: 110, reps: 3)
        heavy.sets.append(SetLog(exerciseID: squat, setIndex: 2, reps: 8, weightKg: 90))

        let history = ProgressiveOverload.history(
            for: squat,
            in: [heavy, session(on: 0, weight: 100, reps: 5)]
        )

        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history.first?.date, day(0))
        // 110x3 (121.0) beats 90x8 (114.0) on the same day.
        XCTAssertEqual(try XCTUnwrap(history.last?.bestWeightKg), 110, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(history.last?.workingVolumeKg), 110 * 3 + 90 * 8, accuracy: 0.001)
    }

    func testPersonalRecordsPickTheBestEstimatedMax() throws {
        let records = ProgressiveOverload.personalRecords(in: [
            session(on: 0, weight: 100, reps: 5),   // 116.7
            session(on: 1, weight: 120, reps: 2)    // 128.0
        ])

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(try XCTUnwrap(records.first?.weightKg), 120, accuracy: 0.001)
    }

    func testNewRecordsOnlyFireWhenTheOldOneIsBeaten() {
        let prior = [session(on: 0, weight: 120, reps: 2)]

        XCTAssertTrue(ProgressiveOverload.newRecords(in: session(on: 1, weight: 100, reps: 5), priorSessions: prior).isEmpty)
        XCTAssertEqual(ProgressiveOverload.newRecords(in: session(on: 1, weight: 125, reps: 2), priorSessions: prior).count, 1)
    }

    func testEasyTopSetSuggestsMoreLoad() throws {
        let suggestion = try XCTUnwrap(
            ProgressiveOverload.suggestion(for: squat, in: [session(on: 0, weight: 100, reps: 5, rpe: 7)])
        )

        XCTAssertEqual(try XCTUnwrap(suggestion.suggestedWeightKg), 102.5, accuracy: 0.001)
        XCTAssertEqual(suggestion.suggestedReps, 5)
    }

    func testMaximalTopSetHoldsTheLoad() throws {
        let suggestion = try XCTUnwrap(
            ProgressiveOverload.suggestion(for: squat, in: [session(on: 0, weight: 100, reps: 5, rpe: 10)])
        )

        XCTAssertEqual(try XCTUnwrap(suggestion.suggestedWeightKg), 100, accuracy: 0.001)
        XCTAssertTrue(suggestion.rationale.contains("Same weight"))
    }

    func testStalledStrengthWithoutRPESuggestsARepInstead() throws {
        let suggestion = try XCTUnwrap(
            ProgressiveOverload.suggestion(for: squat, in: [
                session(on: 0, weight: 100, reps: 5),
                session(on: 3, weight: 100, reps: 5),
                session(on: 6, weight: 100, reps: 5)
            ])
        )

        XCTAssertEqual(try XCTUnwrap(suggestion.suggestedWeightKg), 100, accuracy: 0.001)
        XCTAssertEqual(suggestion.suggestedReps, 6)
    }

    func testNoHistoryMeansNoSuggestion() {
        XCTAssertNil(ProgressiveOverload.suggestion(for: squat, in: []))
    }

    func testRPERejectsOutOfRangeValues() {
        XCTAssertNil(RPE(4.5))
        XCTAssertNil(RPE(10.5))
        XCTAssertEqual(RPE(8.3)?.value, 8.5)
    }
}
