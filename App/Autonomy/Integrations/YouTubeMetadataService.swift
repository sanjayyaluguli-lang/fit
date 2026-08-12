import Foundation
import AutonomyKit

enum YouTubeMetadataError: Error {
    case noAPIKey
    case notFound
    case http(Int)
}

/// Title, channel, duration and chapters for a video ID.
///
/// Optional by design. Without a key the app falls back to a manually typed
/// title, and everything else — saving, scheduling, playing, logging — is
/// unaffected. The key is read from the app's own config, never bundled into
/// the repo.
actor YouTubeMetadataService {
    static let shared = YouTubeMetadataService()

    struct Metadata: Sendable {
        let title: String
        let channel: String
        let durationSeconds: Int?
        let chapters: [VideoChapter]
    }

    private let apiKey: String?
    private let session: URLSession
    private var cache: [String: Metadata] = [:]

    init(
        apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "YouTubeAPIKey") as? String,
        session: URLSession = .shared
    ) {
        self.apiKey = (apiKey?.isEmpty == false) ? apiKey : nil
        self.session = session
    }

    func metadata(for videoID: String) async throws -> Metadata {
        if let cached = cache[videoID] { return cached }
        guard let apiKey else { throw YouTubeMetadataError.noAPIKey }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "id", value: videoID),
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components?.url else { throw YouTubeMetadataError.notFound }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw YouTubeMetadataError.http(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(VideoList.self, from: data)
        guard let item = decoded.items.first else { throw YouTubeMetadataError.notFound }

        let metadata = Metadata(
            title: item.snippet.title,
            channel: item.snippet.channelTitle,
            durationSeconds: Self.seconds(fromISO8601Duration: item.contentDetails.duration),
            chapters: YouTubeLinkParser.chapters(fromDescription: item.snippet.description)
        )
        cache[videoID] = metadata
        return metadata
    }

    /// Parses the `PT1H2M3S` duration format. Days are ignored — no workout is
    /// a day long.
    static func seconds(fromISO8601Duration duration: String) -> Int? {
        guard duration.hasPrefix("PT") else { return nil }
        var total = 0
        var current = 0
        for character in duration.dropFirst(2) {
            if let digit = character.wholeNumberValue, character.isNumber {
                current = current * 10 + digit
            } else {
                switch character {
                case "H": total += current * 3600
                case "M": total += current * 60
                case "S": total += current
                default: return nil
                }
                current = 0
            }
        }
        return total
    }

    private struct VideoList: Decodable {
        struct Item: Decodable {
            struct Snippet: Decodable {
                let title: String
                let description: String
                let channelTitle: String
            }
            struct ContentDetails: Decodable {
                let duration: String
            }
            let snippet: Snippet
            let contentDetails: ContentDetails
        }
        let items: [Item]
    }
}
