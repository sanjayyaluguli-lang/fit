import SwiftUI
import Charts
import AutonomyKit

/// Long windows by default. A year of weight or a year of estimated maxes tells
/// the truth; seven days tells you about salt and sleep.
struct ProgressDashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var window: Window = .year

    enum Window: String, CaseIterable, Identifiable {
        case quarter = "3 months"
        case year = "1 year"
        case twoYears = "2 years"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .quarter: return 90
            case .year: return 365
            case .twoYears: return 730
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Window", selection: $window) {
                    ForEach(Window.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                independenceCard
                weightCard
                consistencyCard
                recordsCard
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Progress")
    }

    private var independenceCard: some View {
        let report = model.independence
        return Card(title: "Independence") {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(Int(report.score.rounded()))")
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text(report.stage.headline)
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
            }
            Text(report.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            ForEach(report.components, id: \.label) { component in
                HStack {
                    Text(component.label)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(component.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.primaryText)
                }
            }
        }
    }

    private var weightCard: some View {
        let points = weightPoints
        let summary = Trends.summarise(
            points,
            smoothingWindow: 7,
            meaningfulMonthlyChange: 0.4,
            unit: "kg",
            lowerIsBetter: model.data.profile.goals.contains(.fatLoss)
        )
        return Card(title: "Weight") {
            if points.count < 2 {
                Text("Not enough history yet. Two readings a week is plenty.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Chart {
                    ForEach(points, id: \.date) { point in
                        PointMark(x: .value("Date", point.date), y: .value("kg", point.value))
                            .foregroundStyle(Theme.secondaryText.opacity(0.35))
                            .symbolSize(12)
                    }
                    ForEach(summary.smoothed, id: \.date) { point in
                        LineMark(x: .value("Date", point.date), y: .value("kg", point.value))
                            .foregroundStyle(Theme.accent)
                            .interpolationMethod(.monotone)
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: .automatic(includesZero: false))

                Text(summary.caption)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var consistencyCard: some View {
        let weeks = min(window.days / 7, 104)
        let result = Trends.weeksTrained(sessions: model.data.sessions, weeks: weeks)
        return Card(title: "Consistency") {
            Text("\(result.trained) of \(result.total) weeks")
                .font(.title2)
                .foregroundStyle(Theme.primaryText)
            Text("Weeks with at least one session. Missing one doesn't reset anything.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private var recordsCard: some View {
        let records = ProgressiveOverload.personalRecords(in: model.data.sessions).prefix(6)
        return Card(title: "Bests") {
            if records.isEmpty {
                Text("Log a few sets with weight and reps and they'll show up here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            ForEach(Array(records)) { record in
                HStack {
                    Text(model.data.exercise(record.exerciseID)?.name ?? "Exercise")
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Text("\(Int(record.weightKg.rounded())) kg × \(record.reps)")
                        .foregroundStyle(Theme.secondaryText)
                }
                .font(.subheadline)
            }
        }
    }

    private var weightPoints: [TrendPoint] {
        let start = Calendar.current.date(byAdding: .day, value: -window.days, to: Date()) ?? Date()
        return model.data.bodyMetrics
            .filter { $0.kind == .weightKg && $0.date >= start }
            .map { TrendPoint(date: $0.date, value: $0.value) }
            .sorted { $0.date < $1.date }
    }
}
