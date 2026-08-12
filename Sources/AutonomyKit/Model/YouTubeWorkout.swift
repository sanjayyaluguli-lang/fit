import Foundation

public struct VideoChapter: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var startSeconds: Int

    public init(id: UUID = UUID(), title: String, startSeconds: Int) {
        self.id = id
        self.title = title
        self.startSeconds = startSeconds
    }

    public var timestamp: String {
        let h = startSeconds / 3600
        let m = (startSeconds % 3600) / 60
        let s = startSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

/// A YouTube session saved into the library. Metadata is best-effort: if the
/// API key is absent or the fetch fails, the video ID alone is enough to save,
/// play and log — the app never blocks on the network.
public struct YouTubeWorkout: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var videoID: String
    public var title: String
    public var channel: String
    public var durationSeconds: Int?
    public var chapters: [VideoChapter]
    public var style: TrainingStyle
    /// Starting offset if the owner saved a link with a timestamp.
    public var startSeconds: Int?
    public var addedAt: Date
    public var lastCompletedAt: Date?
    public var timesCompleted: Int
    public var rating: Int?
    public var notes: String

    public init(
        id: UUID = UUID(),
        videoID: String,
        title: String = "",
        channel: String = "",
        durationSeconds: Int? = nil,
        chapters: [VideoChapter] = [],
        style: TrainingStyle = .conditioning,
        startSeconds: Int? = nil,
        addedAt: Date = Date(),
        lastCompletedAt: Date? = nil,
        timesCompleted: Int = 0,
        rating: Int? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.videoID = videoID
        self.title = title
        self.channel = channel
        self.durationSeconds = durationSeconds
        self.chapters = chapters
        self.style = style
        self.startSeconds = startSeconds
        self.addedAt = addedAt
        self.lastCompletedAt = lastCompletedAt
        self.timesCompleted = timesCompleted
        self.rating = rating
        self.notes = notes
    }

    public var watchURL: URL? {
        var components = URLComponents(string: "https://www.youtube.com/watch")
        var items = [URLQueryItem(name: "v", value: videoID)]
        if let startSeconds, startSeconds > 0 {
            items.append(URLQueryItem(name: "t", value: "\(startSeconds)"))
        }
        components?.queryItems = items
        return components?.url
    }

    public var displayTitle: String {
        title.isEmpty ? "YouTube session \(videoID)" : title
    }
}

/// An owner-curated set of videos — "travel week", "20 min when I'm wrecked",
/// "Sunday mobility". Collections can be scheduled onto days.
public struct YouTubeCollection: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var workoutIDs: [UUID]
    public var note: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        workoutIDs: [UUID] = [],
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.workoutIDs = workoutIDs
        self.note = note
        self.createdAt = createdAt
    }
}
