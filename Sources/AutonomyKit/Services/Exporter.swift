import Foundation

/// Everything the owner has, in formats they can open without this app.
///
/// This is a hard requirement, not a feature: an app about not depending on
/// things must be leaveable. JSON is the full fidelity copy; the CSVs are what
/// a spreadsheet can actually use.
public enum Exporter {

    public struct Bundle: Sendable {
        /// File name -> contents.
        public let files: [String: Data]
    }

    public static func json(_ data: AutonomyData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(data)
    }

    public static func bundle(_ data: AutonomyData) throws -> Bundle {
        var files: [String: Data] = [:]
        files["autonomy.json"] = try json(data)
        files["sessions.csv"] = Data(sessionsCSV(data).utf8)
        files["sets.csv"] = Data(setsCSV(data).utf8)
        files["body-metrics.csv"] = Data(bodyMetricsCSV(data).utf8)
        files["habits.csv"] = Data(habitsCSV(data).utf8)
        files["daily-health.csv"] = Data(healthCSV(data).utf8)
        return Bundle(files: files)
    }

    // MARK: - CSV

    public static func sessionsCSV(_ data: AutonomyData) -> String {
        var rows = [["date", "title", "source", "style", "duration_min", "feel", "rating", "volume_kg", "deviated", "notes"]]
        for session in data.sessions.sorted(by: { $0.date < $1.date }) {
            rows.append([
                iso(session.date),
                session.title,
                describe(session.source),
                session.style.rawValue,
                session.durationMinutes.map(String.init) ?? "",
                session.feel?.rawValue ?? "",
                session.rating.map(String.init) ?? "",
                String(format: "%.1f", session.totalVolumeKg),
                session.deviatedFromPlan ? "yes" : "no",
                session.notes
            ])
        }
        return csv(rows)
    }

    public static func setsCSV(_ data: AutonomyData) -> String {
        var rows = [["date", "exercise", "set", "reps", "weight_kg", "seconds", "distance_m", "rpe", "warmup"]]
        let names = Dictionary(uniqueKeysWithValues: data.exercises.map { ($0.id, $0.name) })
        for session in data.sessions.sorted(by: { $0.date < $1.date }) {
            for set in session.sets.sorted(by: { $0.setIndex < $1.setIndex }) {
                rows.append([
                    iso(session.date),
                    names[set.exerciseID] ?? set.exerciseID.uuidString,
                    String(set.setIndex),
                    set.reps.map(String.init) ?? "",
                    set.weightKg.map { String($0) } ?? "",
                    set.seconds.map(String.init) ?? "",
                    set.distanceMeters.map { String($0) } ?? "",
                    set.rpe.map { String($0.value) } ?? "",
                    set.isWarmup ? "yes" : "no"
                ])
            }
        }
        return csv(rows)
    }

    public static func bodyMetricsCSV(_ data: AutonomyData) -> String {
        var rows = [["date", "metric", "value", "unit", "source"]]
        for metric in data.bodyMetrics.sorted(by: { $0.date < $1.date }) {
            rows.append([
                iso(metric.date),
                metric.kind.rawValue,
                String(metric.value),
                metric.kind.unit,
                metric.importedFromHealth ? "health" : "manual"
            ])
        }
        return csv(rows)
    }

    public static func habitsCSV(_ data: AutonomyData) -> String {
        var rows = [["date", "habit", "completed", "value", "note"]]
        let titles = Dictionary(uniqueKeysWithValues: data.habits.map { ($0.id, $0.title) })
        for log in data.habitLogs.sorted(by: { $0.date < $1.date }) {
            rows.append([
                iso(log.date),
                titles[log.habitID] ?? log.habitID.uuidString,
                log.completed ? "yes" : "no",
                log.value.map { String($0) } ?? "",
                log.note
            ])
        }
        return csv(rows)
    }

    public static func healthCSV(_ data: AutonomyData) -> String {
        var rows = [["date", "steps", "active_kcal", "resting_hr", "hrv", "sleep_min", "weight_kg", "recovery", "strain"]]
        let recoveryByDay = Dictionary(
            data.recovery.map { (Calendar.current.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for day in data.healthDays.sorted(by: { $0.date < $1.date }) {
            let recovery = recoveryByDay[Calendar.current.startOfDay(for: day.date)]
            rows.append([
                iso(day.date),
                day.steps.map(String.init) ?? "",
                day.activeEnergyKcal.map { String($0) } ?? "",
                day.restingHeartRate.map { String($0) } ?? "",
                day.hrvSDNN.map { String($0) } ?? "",
                day.sleepMinutes.map(String.init) ?? "",
                day.weightKg.map { String($0) } ?? "",
                recovery?.recoveryScore.map { String($0) } ?? "",
                recovery?.strain.map { String($0) } ?? ""
            ])
        }
        return csv(rows)
    }

    // MARK: - Helpers

    private static func describe(_ source: SessionSource) -> String {
        switch source {
        case .plan(let id): return "plan:\(id.uuidString)"
        case .youtube(let id): return "youtube:\(id)"
        case .appleFitness: return "apple-fitness"
        case .freeform: return "freeform"
        }
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func csv(_ rows: [[String]]) -> String {
        rows.map { row in row.map(escape).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
