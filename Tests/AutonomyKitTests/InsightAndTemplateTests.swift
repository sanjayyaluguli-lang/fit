import XCTest
@testable import AutonomyKit

final class InsightAndTemplateTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private lazy var now = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    private func daysAgo(_ count: Int) -> Date {
        calendar.date(byAdding: .day, value: -count, to: now)!
    }

    func testAnEmptyAppSaysNothingRatherThanInventingEncouragement() {
        let insight = InsightEngine.headline(from: AutonomyData.firstRun(), asOf: now, calendar: calendar)

        XCTAssertNil(insight)
    }

    func testShortSleepOutranksEverythingElse() throws {
        var data = AutonomyData.firstRun()
        data.healthDays = (1...6).map { HealthDaily(date: daysAgo($0), sleepMinutes: 330) }
        data.sessions = (1...12).map { WorkoutSession(date: daysAgo($0 * 7), source: .freeform) }

        let insight = try XCTUnwrap(InsightEngine.headline(from: data, asOf: now, calendar: calendar))

        XCTAssertEqual(insight.id, "sleep")
        XCTAssertEqual(insight.tone, .caution)
    }

    func testConsistencyIsCelebratedWithoutStreakLanguage() throws {
        var data = AutonomyData.firstRun()
        data.sessions = (0...11).map { WorkoutSession(date: daysAgo($0 * 7 + 1), source: .freeform) }

        let insight = try XCTUnwrap(InsightEngine.headline(from: data, asOf: now, calendar: calendar))

        XCTAssertFalse(insight.body.lowercased().contains("streak"))
        XCTAssertEqual(insight.tone, .affirming)
    }

    func testRecentPRIsSurfaced() throws {
        var data = AutonomyData.firstRun()
        let squat = try XCTUnwrap(data.exercises.first)
        data.sessions = [
            WorkoutSession(
                date: daysAgo(2),
                source: .freeform,
                sets: [SetLog(exerciseID: squat.id, setIndex: 1, reps: 5, weightKg: 100)]
            )
        ]

        let candidates = InsightEngine.candidates(from: data, asOf: now, calendar: calendar)

        XCTAssertTrue(candidates.contains { $0.id == "pr" && $0.title.contains(squat.name) })
    }

    func testTemplatesBuildAgainstTheOwnersLibraryAndStayUnowned() throws {
        let library = ExerciseCatalog.seed()

        for template in PeriodizationTemplates.all() {
            let plans = template.build(library)
            XCTAssertFalse(plans.isEmpty, "\(template.name) produced no plans")
            for plan in plans {
                XCTAssertFalse(plan.isUserCreated)
                XCTAssertEqual(plan.derivedFromTemplateID, template.id)
                XCTAssertFalse(plan.plannedExercises.isEmpty)
            }
        }
    }

    func testTemplatesSkipExercisesTheOwnerDoesNotHave() {
        let sparse = [Exercise(name: "Back Squat", isUserCreated: false)]

        let plans = PeriodizationTemplates.minimalStrength().build(sparse)

        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].plannedExercises.count, 1)
    }

    func testEditingATemplatePlanMakesItYours() {
        var plan = PeriodizationTemplates.upperLower().build(ExerciseCatalog.seed())[0]
        XCTAssertFalse(plan.isUserCreated)

        plan.markEdited()

        XCTAssertTrue(plan.isUserCreated)
        XCTAssertEqual(plan.derivedFromTemplateID, PeriodizationTemplates.upperLower().id)
    }
}
