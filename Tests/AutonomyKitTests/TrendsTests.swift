import XCTest
@testable import AutonomyKit

final class TrendsTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private lazy var start = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_600_000_000))

    private func series(_ values: [Double]) -> [TrendPoint] {
        values.enumerated().map { index, value in
            TrendPoint(date: calendar.date(byAdding: .day, value: index, to: start)!, value: value)
        }
    }

    func testMovingAverageIsTrailingSoOldPointsNeverMove() {
        let smoothed = Trends.movingAverage(series([1, 2, 3, 4, 5]), window: 3)

        XCTAssertEqual(smoothed.map(\.value), [1, 1.5, 2, 3, 4])
    }

    func testSlopePerDayOnALine() throws {
        let slope = try XCTUnwrap(Trends.slopePerDay(series([0, 1, 2, 3, 4, 5])))

        XCTAssertEqual(slope, 1, accuracy: 0.0001)
    }

    func testSlopeNeedsTwoPoints() {
        XCTAssertNil(Trends.slopePerDay(series([5])))
        XCTAssertNil(Trends.slopePerDay([]))
    }

    func testSteadyWeightReadsAsFlatNotAsProgress() {
        let noisy = series([80.0, 80.4, 79.8, 80.1, 80.2, 79.9, 80.0, 80.3, 79.7, 80.1])

        let summary = Trends.summarise(noisy, meaningfulMonthlyChange: 0.4, unit: "kg", lowerIsBetter: true)

        XCTAssertEqual(summary.direction, .flat)
        XCTAssertTrue(summary.caption.contains("steady"))
    }

    func testSustainedLossIsReportedAsProgressWhenLowerIsBetter() throws {
        let losing = series((0..<60).map { 90 - Double($0) * 0.03 })

        let summary = Trends.summarise(losing, meaningfulMonthlyChange: 0.4, unit: "kg", lowerIsBetter: true)

        XCTAssertEqual(summary.direction, .falling)
        XCTAssertLessThan(try XCTUnwrap(summary.ratePerMonth), 0)
        XCTAssertTrue(summary.caption.contains("your way"))
    }

    func testRisingWeightIsFlaggedGentlyWhenLowerIsBetter() {
        let gaining = series((0..<60).map { 80 + Double($0) * 0.05 })

        let summary = Trends.summarise(gaining, meaningfulMonthlyChange: 0.4, unit: "kg", lowerIsBetter: true)

        XCTAssertEqual(summary.direction, .rising)
        XCTAssertTrue(summary.caption.contains("not a panic"))
    }

    func testMonthlyAveragesBucketByCalendarMonth() {
        let january = calendar.date(from: DateComponents(year: 2025, month: 1, day: 5))!
        let alsoJanuary = calendar.date(from: DateComponents(year: 2025, month: 1, day: 25))!
        let february = calendar.date(from: DateComponents(year: 2025, month: 2, day: 3))!

        let monthly = Trends.monthlyAverages(
            [
                TrendPoint(date: january, value: 10),
                TrendPoint(date: alsoJanuary, value: 20),
                TrendPoint(date: february, value: 40)
            ],
            calendar: calendar
        )

        XCTAssertEqual(monthly.count, 2)
        XCTAssertEqual(monthly[0].value, 15)
        XCTAssertEqual(monthly[1].value, 40)
    }

    func testWeeksTrainedCountsWeeksNotStreaks() {
        let now = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let sessions = [0, 1, 8, 9, 30].map { offset in
            WorkoutSession(date: calendar.date(byAdding: .day, value: -offset, to: now)!)
        }

        let result = Trends.weeksTrained(sessions: sessions, asOf: now, weeks: 12, calendar: calendar)

        XCTAssertEqual(result.total, 12)
        // Five sessions clustered into three stretches — never five "streak days".
        XCTAssertGreaterThanOrEqual(result.trained, 3)
        XCTAssertLessThanOrEqual(result.trained, 5)
    }
}
