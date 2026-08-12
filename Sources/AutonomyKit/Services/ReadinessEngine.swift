import Foundation

/// Rolling personal baselines. Readiness is always relative to the owner's own
/// recent normal — never to a population average.
public struct PhysiologyBaseline: Codable, Hashable, Sendable {
    public var hrv: Double?
    public var restingHeartRate: Double?
    public var sleepMinutes: Double?

    public init(hrv: Double? = nil, restingHeartRate: Double? = nil, sleepMinutes: Double? = nil) {
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleepMinutes = sleepMinutes
    }

    /// Trailing mean over the given window, ending at `asOf` (exclusive of the
    /// day itself so today's reading is compared against, not folded into, the
    /// baseline).
    public static func trailing(
        from days: [HealthDaily],
        recovery: [RecoverySnapshot] = [],
        asOf: Date,
        window: Int = 30,
        calendar: Calendar = .current
    ) -> PhysiologyBaseline {
        guard let start = calendar.date(byAdding: .day, value: -window, to: asOf) else {
            return PhysiologyBaseline()
        }
        let today = calendar.startOfDay(for: asOf)
        let inWindow = days.filter { $0.date >= start && calendar.startOfDay(for: $0.date) < today }
        let recoveryInWindow = recovery.filter { $0.date >= start && calendar.startOfDay(for: $0.date) < today }

        let hrvValues = inWindow.compactMap(\.hrvSDNN) + recoveryInWindow.compactMap(\.hrvMilliseconds)
        let rhrValues = inWindow.compactMap(\.restingHeartRate) + recoveryInWindow.compactMap(\.restingHeartRate)
        let sleepValues = inWindow.compactMap(\.sleepMinutes).map(Double.init)

        return PhysiologyBaseline(
            hrv: mean(hrvValues),
            restingHeartRate: mean(rhrValues),
            sleepMinutes: mean(sleepValues)
        )
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

public struct ReadinessContribution: Hashable, Sendable {
    public let label: String
    /// 0–100 after normalisation.
    public let score: Double
    public let weight: Double
    public let detail: String
}

public enum ReadinessBand: String, Sendable {
    case ready
    case steady
    case gentle

    public var headline: String {
        switch self {
        case .ready: return "Good to push"
        case .steady: return "Train as planned"
        case .gentle: return "Keep it easy"
        }
    }
}

/// Confidence is surfaced instead of hidden: a readiness number built from one
/// subjective tap should not look like one built from Whoop plus sleep plus HRV.
public enum ReadinessConfidence: String, Sendable {
    case none
    case low
    case medium
    case high
}

public struct Readiness: Sendable {
    public let date: Date
    /// 0–100, nil when there is genuinely nothing to go on.
    public let score: Double?
    public let band: ReadinessBand?
    public let confidence: ReadinessConfidence
    public let contributions: [ReadinessContribution]
    public let guidance: String
}

/// Blends wearable data with the owner's own read of the day into one number,
/// and — more importantly — one sentence of plain guidance.
///
/// The subjective check-in carries real weight (0.20) deliberately. An app that
/// overrides how someone says they feel teaches them to stop noticing.
public enum ReadinessEngine {

    public struct Weights: Sendable {
        public var recovery: Double = 0.40
        public var sleep: Double = 0.25
        public var hrv: Double = 0.15
        public var restingHeartRate: Double = 0.10
        public var subjective: Double = 0.20

        public init() {}
    }

    public static func evaluate(
        date: Date = Date(),
        recovery: RecoverySnapshot? = nil,
        health: HealthDaily? = nil,
        checkIn: SubjectiveCheckIn? = nil,
        baseline: PhysiologyBaseline = PhysiologyBaseline(),
        sleepNeedMinutes: Double = 450,
        weights: Weights = Weights()
    ) -> Readiness {
        var contributions: [ReadinessContribution] = []

        if let recoveryScore = recovery?.recoveryScore {
            contributions.append(
                ReadinessContribution(
                    label: "Recovery",
                    score: clamp(recoveryScore),
                    weight: weights.recovery,
                    detail: "\(Int(recoveryScore.rounded()))% from \(recovery?.provider.rawValue ?? "wearable")"
                )
            )
        }

        if let sleep = sleepComponent(recovery: recovery, health: health, need: sleepNeedMinutes) {
            contributions.append(
                ReadinessContribution(label: "Sleep", score: sleep.0, weight: weights.sleep, detail: sleep.1)
            )
        }

        let hrvToday = health?.hrvSDNN ?? recovery?.hrvMilliseconds
        if let hrvToday, let hrvBaseline = baseline.hrv, hrvBaseline > 0 {
            let ratio = hrvToday / hrvBaseline
            let score = clamp(70 + (ratio - 1) * 150)
            let delta = Int(((ratio - 1) * 100).rounded())
            contributions.append(
                ReadinessContribution(
                    label: "HRV",
                    score: score,
                    weight: weights.hrv,
                    detail: delta == 0 ? "at your baseline" : "\(delta > 0 ? "+" : "")\(delta)% vs baseline"
                )
            )
        }

        let rhrToday = health?.restingHeartRate ?? recovery?.restingHeartRate
        if let rhrToday, let rhrBaseline = baseline.restingHeartRate, rhrBaseline > 0 {
            // Five beats above baseline is a meaningful signal; scale to that.
            let delta = rhrToday - rhrBaseline
            let score = clamp(70 - (delta / 5) * 30)
            contributions.append(
                ReadinessContribution(
                    label: "Resting HR",
                    score: score,
                    weight: weights.restingHeartRate,
                    detail: String(format: "%+.0f bpm vs baseline", delta)
                )
            )
        }

        if let checkIn {
            var score = Double(clampInt(checkIn.energy, 1, 5) - 1) / 4 * 100
            if let stress = checkIn.stress {
                score -= Double(clampInt(stress, 1, 5) - 1) / 4 * 15
            }
            contributions.append(
                ReadinessContribution(
                    label: "How you feel",
                    score: clamp(score),
                    weight: weights.subjective,
                    detail: "energy \(checkIn.energy)/5"
                )
            )
        }

        let totalWeight = contributions.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return Readiness(
                date: date,
                score: nil,
                band: nil,
                confidence: .none,
                contributions: [],
                guidance: "Nothing synced yet today. Tell the app how you feel and that's enough to go on."
            )
        }

        let score = contributions.reduce(0) { $0 + $1.score * $1.weight } / totalWeight
        let band: ReadinessBand = score >= 70 ? .ready : (score >= 45 ? .steady : .gentle)

        return Readiness(
            date: date,
            score: score,
            band: band,
            confidence: confidence(for: contributions),
            contributions: contributions.sorted { $0.weight > $1.weight },
            guidance: guidance(for: band, contributions: contributions)
        )
    }

    private static func sleepComponent(
        recovery: RecoverySnapshot?,
        health: HealthDaily?,
        need: Double
    ) -> (Double, String)? {
        if let performance = recovery?.sleepPerformance {
            return (clamp(performance), "\(Int(performance.rounded()))% of need")
        }
        if let minutes = health?.sleepMinutes, need > 0 {
            let ratio = Double(minutes) / need
            let hours = Double(minutes) / 60
            return (clamp(ratio * 100), String(format: "%.1f h", hours))
        }
        return nil
    }

    private static func confidence(for contributions: [ReadinessContribution]) -> ReadinessConfidence {
        let objective = contributions.filter { $0.label != "How you feel" }.count
        switch objective {
        case 0: return .low
        case 1: return .medium
        default: return .high
        }
    }

    private static func guidance(for band: ReadinessBand, contributions: [ReadinessContribution]) -> String {
        let weakest = contributions.min { $0.score < $1.score }
        switch band {
        case .ready:
            return "Everything lines up for a full session. Push the top set if it's there."
        case .steady:
            return "Nothing here says back off. Run the session you planned and judge it by feel."
        case .gentle:
            if let weakest, weakest.score < 45 {
                return "\(weakest.label) is the limiter (\(weakest.detail)). Keep the session, drop a set or two, and call that a win."
            }
            return "Lighter day. Move, don't chase — this is what makes next week possible."
        }
    }

    private static func clamp(_ value: Double, _ low: Double = 0, _ high: Double = 100) -> Double {
        min(max(value, low), high)
    }

    private static func clampInt(_ value: Int, _ low: Int, _ high: Int) -> Int {
        min(max(value, low), high)
    }
}
