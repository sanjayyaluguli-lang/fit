import XCTest
@testable import AutonomyKit

final class IndependenceScoreTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private lazy var now = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    private func daysAgo(_ count: Int) -> Date {
        calendar.date(byAdding: .day, value: -count, to: now)!
    }

    func testFollowingAShippedTemplateScoresLow() {
        let template = WorkoutPlan(name: "Upper", isUserCreated: false)
        let sessions = (1...8).map { index in
            WorkoutSession(date: daysAgo(index * 3), source: .plan(template.id))
        }

        let report = IndependenceScore.evaluate(
            sessions: sessions,
            plans: [template],
            exercises: ExerciseCatalog.seed(),
            reviews: [],
            asOf: now
        )

        XCTAssertEqual(report.stage, .learning)
        XCTAssertLessThan(report.score, 20)
    }

    func testWritingAdaptingAndReviewingScoresHigh() {
        let mine = WorkoutPlan(name: "My Session", isUserCreated: true)
        let sessions = (1...9).map { index in
            WorkoutSession(
                date: daysAgo(index * 3),
                source: .plan(mine.id),
                deviatedFromPlan: index % 3 == 0
            )
        }
        let reviews = (0..<13).map { index in
            WeeklyReview(
                weekStart: daysAgo(index * 7),
                sustainabilityRating: 4,
                selfDirectedAdjustments: ["dropped the third day"],
                completedAt: daysAgo(index * 7)
            )
        }
        let exercises = ExerciseCatalog.seed() + (1...6).map { Exercise(name: "Mine \($0)") }

        let report = IndependenceScore.evaluate(
            sessions: sessions,
            plans: [mine],
            exercises: exercises,
            reviews: reviews,
            asOf: now
        )

        XCTAssertGreaterThan(report.score, 85)
        XCTAssertTrue([.selfDirected, .independent].contains(report.stage))
    }

    func testFreeformSessionsCountAsYourOwn() {
        let sessions = (1...5).map { WorkoutSession(date: daysAgo($0), source: .freeform) }

        let report = IndependenceScore.evaluate(
            sessions: sessions,
            plans: [],
            exercises: [],
            reviews: [],
            asOf: now
        )

        let ownSessions = report.components.first { $0.label == "Your sessions" }
        XCTAssertEqual(ownSessions?.score, 100)
    }

    func testYouTubeSessionOnlyCountsWhenTheOwnerEngagedWithIt() {
        let passive = WorkoutSession(date: daysAgo(1), source: .youtube("abc"))
        let rated = WorkoutSession(date: daysAgo(2), source: .youtube("abc"), rating: 4)

        let report = IndependenceScore.evaluate(
            sessions: [passive, rated],
            plans: [],
            exercises: [],
            reviews: [],
            asOf: now
        )

        let ownSessions = report.components.first { $0.label == "Your sessions" }
        XCTAssertEqual(ownSessions?.score, 50)
    }

    func testEmptyHistoryDoesNotCrashAndSuggestsAStart() {
        let report = IndependenceScore.evaluate(
            sessions: [],
            plans: [],
            exercises: [],
            reviews: [],
            asOf: now
        )

        XCTAssertEqual(report.score, 0)
        XCTAssertEqual(report.stage, .learning)
        XCTAssertFalse(report.summary.isEmpty)
    }

    func testDeviatingFromEverythingIsNotScoredHigherThanSometimes() {
        func score(deviationEvery n: Int) -> Double {
            let sessions = (1...12).map { index in
                WorkoutSession(date: daysAgo(index * 2), source: .freeform, deviatedFromPlan: index % n == 0)
            }
            let component = IndependenceScore.evaluate(
                sessions: sessions, plans: [], exercises: [], reviews: [], asOf: now
            ).components.first { $0.label == "Adjusting as you go" }
            return component?.score ?? 0
        }

        XCTAssertEqual(score(deviationEvery: 3), 95.238, accuracy: 0.01)
        XCTAssertEqual(score(deviationEvery: 1), 100, accuracy: 0.001)
    }
}
