import Foundation

public struct YouTubeLink: Hashable, Sendable {
    public let videoID: String?
    public let playlistID: String?
    public let startSeconds: Int?
}

/// Pure URL/text parsing — no network, no API key. Pasting a link always works
/// offline; metadata enrichment is a separate, failable step.
public enum YouTubeLinkParser {

    private static let idCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    )

    public static func parse(_ input: String) -> YouTubeLink? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // A bare video ID pasted on its own.
        if trimmed.count == 11, isValidID(trimmed) {
            return YouTubeLink(videoID: trimmed, playlistID: nil, startSeconds: nil)
        }

        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: normalized),
              let host = components.host?.lowercased()
        else { return nil }

        let queryItems = components.queryItems ?? []
        let playlistID = queryItems.first { $0.name == "list" }?.value
        let start = seconds(from: queryItems.first { $0.name == "t" || $0.name == "start" }?.value)

        var videoID: String?
        let path = components.path

        if host.hasSuffix("youtu.be") {
            videoID = path.split(separator: "/").first.map(String.init)
        } else if host.hasSuffix("youtube.com") || host.hasSuffix("youtube-nocookie.com") {
            if let v = queryItems.first(where: { $0.name == "v" })?.value {
                videoID = v
            } else {
                // /embed/ID, /shorts/ID, /live/ID, /v/ID
                let parts = path.split(separator: "/").map(String.init)
                if parts.count >= 2, ["embed", "shorts", "live", "v"].contains(parts[0]) {
                    videoID = parts[1]
                }
            }
        } else {
            return nil
        }

        if let id = videoID, !isValidID(id) { videoID = nil }
        guard videoID != nil || playlistID != nil else { return nil }
        return YouTubeLink(videoID: videoID, playlistID: playlistID, startSeconds: start)
    }

    /// Handles `90`, `90s`, `1m30s`, `1h2m3s` and `01:30`.
    public static func seconds(from raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }

        if raw.contains(":") {
            let parts = raw.split(separator: ":").map { Int($0) ?? -1 }
            guard !parts.contains(-1) else { return nil }
            return parts.reduce(0) { $0 * 60 + $1 }
        }

        if let plain = Int(raw) { return plain }

        var total = 0
        var current = 0
        var sawUnit = false
        for character in raw.lowercased() {
            if let digit = character.wholeNumberValue, character.isNumber {
                current = current * 10 + digit
            } else {
                switch character {
                case "h": total += current * 3600
                case "m": total += current * 60
                case "s": total += current
                default: return nil
                }
                sawUnit = true
                current = 0
            }
        }
        guard sawUnit else { return nil }
        return total + current
    }

    /// Pulls a chapter list out of a video description. YouTube's own rule is
    /// that the first timestamp must be 0:00, and we follow it — otherwise a
    /// description that merely mentions "at 4:20" would become a chapter list.
    public static func chapters(fromDescription description: String) -> [VideoChapter] {
        var parsed: [(Int, String)] = []

        for rawLine in description.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let match = leadingTimestamp(in: line) else { continue }
            let title = line
                .dropFirst(match.length)
                .trimmingCharacters(in: CharacterSet(charactersIn: " -–—:|·"))
            guard !title.isEmpty else { continue }
            parsed.append((match.seconds, title))
        }

        guard let first = parsed.first, first.0 == 0 else { return [] }
        return parsed.map { VideoChapter(title: $0.1, startSeconds: $0.0) }
    }

    private static func leadingTimestamp(in line: String) -> (seconds: Int, length: Int)? {
        var digits = ""
        var index = line.startIndex
        while index < line.endIndex, line[index].isNumber || line[index] == ":" {
            digits.append(line[index])
            index = line.index(after: index)
        }
        guard digits.contains(":") else { return nil }
        let parts = digits.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2, parts.count <= 3,
              parts.allSatisfy({ !$0.isEmpty && Int($0) != nil })
        else { return nil }
        let total = parts.reduce(0) { $0 * 60 + (Int($1) ?? 0) }
        return (total, digits.count)
    }

    private static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.unicodeScalars.allSatisfy { idCharacters.contains($0) }
    }
}
