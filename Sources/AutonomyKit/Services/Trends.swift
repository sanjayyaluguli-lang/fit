import Foundation

public struct TrendPoint: Hashable, Sendable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public enum TrendDirection: String, Sendable {
    case rising
    case falling
    case flat
}

public struct TrendSummary: Sendable {
    public let points: [TrendPoint]
    public let smoothed: [TrendPoint]
    public let direction: TrendDirection
    /// Change per 30 days, in the series' own units.
    public let ratePerMonth: Double?
    public let caption: String
}

/// Long-horizon views. The app's default window is a year, not a week — weekly
/// noise is the thing most people quit over.
public enum Trends {

    /// Centred-free trailing moving average. Trailing (not centred) so the last
    /// point never shifts once new data arrives.
    public static func movingAverage(_ points: [TrendPoint], window: Int) -> [TrendPoint] {
        guard window > 1, points.count >= 1 else { return points }
        let sorted = points.sorted { $0.date < $1.date }
        var result: [TrendPoint] = []
        var buffer: [Double] = []

        for point in sorted {
            buffer.append(point.value)
            if buffer.count > window { buffer.removeFirst() }
            let mean = buffer.reduce(0, +) / Double(buffer.count)
            result.append(TrendPoint(date: point.date, value: mean))
        }
        return result
    }

    /// Least-squares slope in units per day. Nil when there's nothing to fit.
    public static func slopePerDay(_ points: [TrendPoint]) -> Double? {
        guard points.count >= 2 else { return nil }
        let sorted = points.sorted { $0.date < $1.date }
        guard let origin = sorted.first?.date else { return nil }

        let xs = sorted.map { $0.date.timeIntervalSince(origin) / 86400 }
        let ys = sorted.map(\.value)
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n

        var numerator = 0.0
        var denominator = 0.0
        for (x, y) in zip(xs, ys) {
            numerator += (x - meanX) * (y - meanY)
            denominator += (x - meanX) * (x - meanX)
        }
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }

    /// - Parameter meaningfulMonthlyChange: below this, the trend is reported as
    ///   flat. Weight in kg wants ~0.4; a strength e1RM wants more.
    public static func summarise(
        _ points: [TrendPoint],
        smoothingWindow: Int = 7,
        meaningfulMonthlyChange: Double = 0.4,
        unit: String = "",
        lowerIsBetter: Bool = false
    ) -> TrendSummary {
        let sorted = points.sorted { $0.date < $1.date }
        let smoothed = movingAverage(sorted, window: smoothingWindow)
        let rate = slopePerDay(smoothed).map { $0 * 30 }

        guard let rate, abs(rate) >= meaningfulMonthlyChange else {
            return TrendSummary(
                points: sorted,
                smoothed: smoothed,
                direction: .flat,
                ratePerMonth: rate,
                caption: sorted.count < 2
                    ? "Not enough history yet."
                    : "Holding steady over this window."
            )
        }

        let direction: TrendDirection = rate > 0 ? .rising : .falling
        let good = lowerIsBetter ? rate < 0 : rate > 0
        let magnitude = String(format: "%.1f", abs(rate))
        let span = describeSpan(sorted)
        let caption = good
            ? "Moving your way — about \(magnitude)\(unit.isEmpty ? "" : " \(unit)") a month across \(span)."
            : "Drifting \(direction == .rising ? "up" : "down") about \(magnitude)\(unit.isEmpty ? "" : " \(unit)") a month across \(span). Worth a look, not a panic."

        return TrendSummary(
            points: sorted,
            smoothed: smoothed,
            direction: direction,
            ratePerMonth: rate,
            caption: caption
        )
    }

    /// Bucket daily values into calendar months — the resolution that makes a
    /// two-year view readable.
    public static func monthlyAverages(
        _ points: [TrendPoint],
        calendar: Calendar = .current
    ) -> [TrendPoint] {
        var buckets: [Date: [Double]] = [:]
        for point in points {
            let components = calendar.dateComponents([.year, .month], from: point.date)
            guard let start = calendar.date(from: components) else { continue }
            buckets[start, default: []].append(point.value)
        }
        return buckets
            .map { TrendPoint(date: $0.key, value: $0.value.reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
    }

    /// Weeks in the window containing at least one logged session. Consistency
    /// is reported as "weeks you showed up", not as a streak that a holiday can
    /// destroy.
    public static func weeksTrained(
        sessions: [WorkoutSession],
        asOf: Date = Date(),
        weeks: Int = 12,
        calendar: Calendar = .current
    ) -> (trained: Int, total: Int) {
        guard weeks > 0, let start = calendar.date(byAdding: .weekOfYear, value: -weeks, to: asOf) else {
            return (0, 0)
        }
        var seen = Set<Int>()
        for session in sessions where session.date >= start && session.date <= asOf {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date)
            if let year = components.yearForWeekOfYear, let week = components.weekOfYear {
                seen.insert(year * 100 + week)
            }
        }
        return (seen.count, weeks)
    }

    private static func describeSpan(_ points: [TrendPoint]) -> String {
        guard let first = points.first?.date, let last = points.last?.date else { return "this window" }
        let days = Int(last.timeIntervalSince(first) / 86400)
        if days >= 600 { return "two years" }
        if days >= 300 { return "a year" }
        if days >= 60 { return "\(days / 30) months" }
        return "\(max(days, 1)) days"
    }
}
