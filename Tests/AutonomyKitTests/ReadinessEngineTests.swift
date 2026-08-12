import XCTest
@testable import AutonomyKit

final class ReadinessEngineTests: XCTestCase {

    func testBlendsRecoverySleepAndSubjectiveIntoReadyBand() throws {
        let readiness = ReadinessEngine.evaluate(
            recovery: RecoverySnapshot(date: .now, recoveryScore: 80, sleepPerformance: 90),
            checkIn: SubjectiveCheckIn(date: .now, energy: 4)
        )

        // 0.40*80 + 0.25*90 + 0.20*75, renormalised over 0.85.
        XCTAssertEqual(try XCTUnwrap(readiness.score), 81.76, accuracy: 0.01)
        XCTAssertEqual(readiness.band, .ready)
        XCTAssertEqual(readiness.confidence, .high)
        XCTAssertEqual(readiness.contributions.count, 3)
    }

    func testNoDataYieldsNoScoreRatherThanAGuess() {
        let readiness = ReadinessEngine.evaluate()

        XCTAssertNil(readiness.score)
        XCTAssertNil(readiness.band)
        XCTAssertEqual(readiness.confidence, .none)
        XCTAssertTrue(readiness.guidance.contains("how you feel"))
    }

    func testSubjectiveOnlyStillProducesAScoreWithLowConfidence() throws {
        let readiness = ReadinessEngine.evaluate(checkIn: SubjectiveCheckIn(date: .now, energy: 2))

        XCTAssertEqual(try XCTUnwrap(readiness.score), 25, accuracy: 0.001)
        XCTAssertEqual(readiness.band, .gentle)
        XCTAssertEqual(readiness.confidence, .low)
    }

    func testStressReducesTheSubjectiveComponent() throws {
        let calm = ReadinessEngine.evaluate(checkIn: SubjectiveCheckIn(date: .now, energy: 4, stress: 1))
        let stressed = ReadinessEngine.evaluate(checkIn: SubjectiveCheckIn(date: .now, energy: 4, stress: 5))

        XCTAssertGreaterThan(try XCTUnwrap(calm.score), try XCTUnwrap(stressed.score))
    }

    func testHRVIsJudgedAgainstThePersonalBaseline() throws {
        let baseline = PhysiologyBaseline(hrv: 60)
        let above = ReadinessEngine.evaluate(
            health: HealthDaily(date: .now, hrvSDNN: 72),
            baseline: baseline
        )
        let below = ReadinessEngine.evaluate(
            health: HealthDaily(date: .now, hrvSDNN: 48),
            baseline: baseline
        )

        // ±20% maps to 100 / 40 around a baseline of 70.
        XCTAssertEqual(try XCTUnwrap(above.score), 100, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(below.score), 40, accuracy: 0.001)
    }

    func testTrailingBaselineExcludesToday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let days: [HealthDaily] = (1...5).map { offset in
            HealthDaily(
                date: calendar.date(byAdding: .day, value: -offset, to: today)!,
                hrvSDNN: 50
            )
        } + [HealthDaily(date: today, hrvSDNN: 200)]

        let baseline = PhysiologyBaseline.trailing(from: days, asOf: today, calendar: calendar)

        XCTAssertEqual(try XCTUnwrap(baseline.hrv), 50, accuracy: 0.001)
    }

    func testGentleBandNamesTheLimiter() {
        let readiness = ReadinessEngine.evaluate(
            recovery: RecoverySnapshot(date: .now, recoveryScore: 20, sleepPerformance: 40),
            checkIn: SubjectiveCheckIn(date: .now, energy: 2)
        )

        XCTAssertEqual(readiness.band, .gentle)
        XCTAssertTrue(readiness.guidance.contains("Recovery"))
    }
}
