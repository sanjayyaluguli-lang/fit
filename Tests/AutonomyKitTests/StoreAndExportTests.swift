import XCTest
@testable import AutonomyKit

final class StoreAndExportTests: XCTestCase {

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("autonomy-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("autonomy.json")
    }

    func testFirstRunSeedsALibraryButNoProgram() async throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = try AutonomyStore(fileURL: url)
        let data = await store.data

        XCTAssertFalse(data.exercises.isEmpty)
        XCTAssertTrue(data.plans.isEmpty, "the app should not decide how the owner trains on day one")
        XCTAssertFalse(data.habits.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testWritesSurviveAReload() async throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = try AutonomyStore(fileURL: url)
        await store.update { data in
            data.sessions.append(WorkoutSession(title: "Evening lift", notes: "felt good"))
        }
        await store.flush()

        let reopened = try AutonomyStore(fileURL: url)
        let sessions = await reopened.data.sessions

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.title, "Evening lift")
    }

    func testCorruptFileFailsLoudlyRatherThanSilentlyResetting() async throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: url)

        do {
            _ = try AutonomyStore(fileURL: url)
            XCTFail("expected a corrupt-file error")
        } catch StoreError.corruptFile {
            // Losing a year of training data to a silent reset is the one
            // unforgivable bug in an app like this.
        }
    }

    func testFutureSchemaIsRejected() async throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        var data = AutonomyData.firstRun()
        data.schemaVersion = AutonomyData.currentSchemaVersion + 1
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(data).write(to: url)

        do {
            _ = try AutonomyStore(fileURL: url)
            XCTFail("expected an unsupported-schema error")
        } catch StoreError.unsupportedSchema(let version) {
            XCTAssertEqual(version, AutonomyData.currentSchemaVersion + 1)
        }
    }

    func testExportBundleContainsEverythingTheOwnerNeeds() throws {
        var data = AutonomyData.firstRun()
        let squat = try XCTUnwrap(data.exercises.first)
        data.sessions = [
            WorkoutSession(
                title: "Squat day",
                sets: [SetLog(exerciseID: squat.id, setIndex: 1, reps: 5, weightKg: 100, rpe: RPE(8))],
                notes: "hard, but fine"
            )
        ]
        data.bodyMetrics = [BodyMetric(date: .now, kind: .weightKg, value: 78.4)]

        let bundle = try Exporter.bundle(data)

        XCTAssertEqual(
            Set(bundle.files.keys),
            ["autonomy.json", "sessions.csv", "sets.csv", "body-metrics.csv", "habits.csv", "daily-health.csv"]
        )

        let sets = try XCTUnwrap(bundle.files["sets.csv"].map { String(decoding: $0, as: UTF8.self) })
        XCTAssertTrue(sets.contains(squat.name))
        XCTAssertTrue(sets.contains("100.0"))
    }

    func testExportedJSONReloadsIntoTheSameData() throws {
        var data = AutonomyData.firstRun()
        data.sessions = [WorkoutSession(title: "Freeform")]

        let encoded = try Exporter.json(data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(AutonomyData.self, from: encoded)

        XCTAssertEqual(restored.sessions.map(\.id), data.sessions.map(\.id))
        XCTAssertEqual(restored.exercises.count, data.exercises.count)
    }

    func testCSVEscapesCommasAndQuotes() {
        let rendered = Exporter.csv([["plain", "with,comma", "with \"quotes\""]])

        XCTAssertEqual(rendered, "plain,\"with,comma\",\"with \"\"quotes\"\"\"\n")
    }

    func testSyncNeverOverwritesOwnerEnteredValues() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let mine = HealthDaily(date: day, steps: 12_000, weightKg: 78.0)
        let imported = HealthDaily(date: day, steps: 9_000, restingHeartRate: 52, weightKg: 79.9)

        let merged = SyncCoordinator.merge([imported], into: [mine])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].steps, 12_000)
        XCTAssertEqual(merged[0].weightKg, 78.0)
        XCTAssertEqual(merged[0].restingHeartRate, 52)
    }

    func testRecoveryResyncReplacesTheSameDay() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let morning = RecoverySnapshot(date: day, recoveryScore: 40)
        let revised = RecoverySnapshot(date: day, recoveryScore: 62)

        let merged = SyncCoordinator.merge([revised], into: [morning])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].recoveryScore, 62)
        XCTAssertEqual(merged[0].id, morning.id, "the row keeps its identity across a resync")
    }
}
