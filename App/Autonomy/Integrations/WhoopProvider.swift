import Foundation
import Security
import AutonomyKit

enum WhoopError: Error, LocalizedError {
    case notConnected
    case unauthorized
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Whoop isn't connected."
        case .unauthorized: return "Whoop needs reconnecting in Settings."
        case .http(let code): return "Whoop returned \(code)."
        }
    }
}

/// Whoop v1 API, read-only.
///
/// The OAuth token lives in the Keychain and never leaves the device; there is
/// no backend of ours in the loop. If Whoop is absent or expired, the app keeps
/// working with Apple Health and the subjective check-in.
struct WhoopProvider: RecoveryDataProvider {
    let tool: ConnectedTool = .whoop

    private let tokens: TokenStore
    private let session: URLSession
    private let baseURL = URL(string: "https://api.prod.whoop.com/developer/v1")!

    init(tokens: TokenStore = .keychain(service: "com.autonomy.whoop"), session: URLSession = .shared) {
        self.tokens = tokens
        self.session = session
    }

    var isAvailable: Bool { tokens.accessToken != nil }

    func recovery(from start: Date, to end: Date) async throws -> [RecoverySnapshot] {
        guard let token = tokens.accessToken else { throw WhoopError.notConnected }

        async let recoveries = fetch(RecoveryPage.self, path: "recovery", token: token, start: start, end: end)
        async let sleeps = fetch(SleepPage.self, path: "activity/sleep", token: token, start: start, end: end)

        let calendar = Calendar.current
        var byDay: [Date: RecoverySnapshot] = [:]

        for record in try await recoveries.records {
            let day = calendar.startOfDay(for: record.created_at)
            var snapshot = byDay[day] ?? RecoverySnapshot(date: day)
            snapshot.recoveryScore = record.score?.recovery_score
            snapshot.hrvMilliseconds = record.score?.hrv_rmssd_milli
            snapshot.restingHeartRate = record.score?.resting_heart_rate
            byDay[day] = snapshot
        }

        for record in try await sleeps.records {
            let day = calendar.startOfDay(for: record.end)
            var snapshot = byDay[day] ?? RecoverySnapshot(date: day)
            snapshot.sleepPerformance = record.score?.sleep_performance_percentage
            snapshot.respiratoryRate = record.score?.respiratory_rate
            byDay[day] = snapshot
        }

        return byDay.values.sorted { $0.date < $1.date }
    }

    // MARK: - Networking

    private func fetch<T: Decodable>(
        _ type: T.Type,
        path: String,
        token: String,
        start: Date,
        end: Date
    ) async throws -> T {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        let formatter = ISO8601DateFormatter()
        components?.queryItems = [
            URLQueryItem(name: "start", value: formatter.string(from: start)),
            URLQueryItem(name: "end", value: formatter.string(from: end)),
            URLQueryItem(name: "limit", value: "25")
        ]
        guard let url = components?.url else { throw WhoopError.notConnected }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WhoopError.http(0) }
        switch http.statusCode {
        case 200: break
        case 401: throw WhoopError.unauthorized
        default: throw WhoopError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    // Field names mirror Whoop's payload rather than being renamed, so the
    // mapping is checkable against their docs at a glance.
    private struct RecoveryPage: Decodable {
        struct Record: Decodable {
            struct Score: Decodable {
                let recovery_score: Double?
                let hrv_rmssd_milli: Double?
                let resting_heart_rate: Double?
            }
            let created_at: Date
            let score: Score?
        }
        let records: [Record]
    }

    private struct SleepPage: Decodable {
        struct Record: Decodable {
            struct Score: Decodable {
                let sleep_performance_percentage: Double?
                let respiratory_rate: Double?
            }
            let end: Date
            let score: Score?
        }
        let records: [Record]
    }
}

/// Minimal Keychain wrapper. Tokens are the only secret the app holds, and they
/// stay out of UserDefaults and out of any backup that isn't the device's own.
struct TokenStore {
    var accessToken: String? { read("access") }
    var refreshToken: String? { read("refresh") }

    private let read: (String) -> String?
    private let write: (String, String?) -> Void

    static func keychain(service: String) -> TokenStore {
        TokenStore(
            read: { account in
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                var item: CFTypeRef?
                guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
                      let data = item as? Data
                else { return nil }
                return String(data: data, encoding: .utf8)
            },
            write: { account, value in
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account
                ]
                SecItemDelete(query as CFDictionary)
                guard let value, let data = value.data(using: .utf8) else { return }
                var insert = query
                insert[kSecValueData as String] = data
                insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                SecItemAdd(insert as CFDictionary, nil)
            }
        )
    }

    func store(access: String?, refresh: String?) {
        write("access", access)
        write("refresh", refresh)
    }

    func clear() {
        write("access", nil)
        write("refresh", nil)
    }
}
