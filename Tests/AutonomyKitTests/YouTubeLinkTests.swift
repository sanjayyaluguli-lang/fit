import XCTest
@testable import AutonomyKit

final class YouTubeLinkTests: XCTestCase {

    func testStandardWatchURL() throws {
        let link = try XCTUnwrap(YouTubeLinkParser.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=90s"))

        XCTAssertEqual(link.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(link.startSeconds, 90)
        XCTAssertNil(link.playlistID)
    }

    func testShortLinkWithTimestamp() throws {
        let link = try XCTUnwrap(YouTubeLinkParser.parse("https://youtu.be/dQw4w9WgXcQ?t=1m30s"))

        XCTAssertEqual(link.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(link.startSeconds, 90)
    }

    func testShortsEmbedAndLivePaths() {
        XCTAssertEqual(YouTubeLinkParser.parse("https://www.youtube.com/shorts/dQw4w9WgXcQ")?.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(YouTubeLinkParser.parse("https://www.youtube.com/embed/dQw4w9WgXcQ")?.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(YouTubeLinkParser.parse("https://www.youtube.com/live/dQw4w9WgXcQ")?.videoID, "dQw4w9WgXcQ")
    }

    func testPlaylistLink() throws {
        let link = try XCTUnwrap(YouTubeLinkParser.parse("https://www.youtube.com/playlist?list=PL1234567890"))

        XCTAssertEqual(link.playlistID, "PL1234567890")
        XCTAssertNil(link.videoID)
    }

    func testMissingSchemeAndBareIDStillWork() {
        XCTAssertEqual(YouTubeLinkParser.parse("youtube.com/watch?v=dQw4w9WgXcQ")?.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(YouTubeLinkParser.parse("dQw4w9WgXcQ")?.videoID, "dQw4w9WgXcQ")
    }

    func testNonYouTubeLinksAreRejected() {
        XCTAssertNil(YouTubeLinkParser.parse("https://vimeo.com/12345"))
        XCTAssertNil(YouTubeLinkParser.parse(""))
        XCTAssertNil(YouTubeLinkParser.parse("not a link"))
    }

    func testTimestampFormats() {
        XCTAssertEqual(YouTubeLinkParser.seconds(from: "90"), 90)
        XCTAssertEqual(YouTubeLinkParser.seconds(from: "90s"), 90)
        XCTAssertEqual(YouTubeLinkParser.seconds(from: "1h2m3s"), 3723)
        XCTAssertEqual(YouTubeLinkParser.seconds(from: "01:30"), 90)
        XCTAssertEqual(YouTubeLinkParser.seconds(from: "1:00:00"), 3600)
        XCTAssertNil(YouTubeLinkParser.seconds(from: "soon"))
    }

    func testChaptersRequireAZeroStart() {
        let description = """
        Follow along session.
        0:00 Warm up
        5:30 Main block
        22:15 Cool down
        Subscribe etc.
        """

        let chapters = YouTubeLinkParser.chapters(fromDescription: description)

        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters[1].title, "Main block")
        XCTAssertEqual(chapters[1].startSeconds, 330)
        XCTAssertEqual(chapters[2].timestamp, "22:15")
    }

    func testDescriptionWithoutAZeroStartIsNotAChapterList() {
        let description = "Great cue at 4:20 in this one, watch that part."

        XCTAssertTrue(YouTubeLinkParser.chapters(fromDescription: description).isEmpty)
    }

    func testWatchURLRoundTrip() throws {
        let workout = YouTubeWorkout(videoID: "dQw4w9WgXcQ", startSeconds: 45)
        let url = try XCTUnwrap(workout.watchURL)

        XCTAssertEqual(url.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=45")
    }
}
