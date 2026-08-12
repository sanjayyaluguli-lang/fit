import SwiftUI
import AutonomyKit

struct YouTubeLibraryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAdd = false

    var body: some View {
        List {
            if model.data.youtubeWorkouts.isEmpty {
                Text("Paste any YouTube link and it becomes a session you can schedule, log and rate.")
                    .foregroundStyle(Theme.secondaryText)
            }

            Section("Saved") {
                ForEach(model.data.youtubeWorkouts.sorted { $0.addedAt > $1.addedAt }) { workout in
                    YouTubeRow(workout: workout)
                }
                .onDelete { offsets in
                    let sorted = model.data.youtubeWorkouts.sorted { $0.addedAt > $1.addedAt }
                    let ids = offsets.map { sorted[$0].id }
                    model.edit { data in
                        data.youtubeWorkouts.removeAll { ids.contains($0.id) }
                    }
                }
            }

            if !model.data.collections.isEmpty {
                Section("Collections") {
                    ForEach(model.data.collections) { collection in
                        VStack(alignment: .leading) {
                            Text(collection.name).foregroundStyle(Theme.primaryText)
                            Text("\(collection.workoutIDs.count) sessions")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("YouTube")
        .toolbar {
            Button { showingAdd = true } label: { Label("Add", systemImage: "plus") }
        }
        .sheet(isPresented: $showingAdd) { AddYouTubeView() }
    }
}

struct YouTubeRow: View {
    @EnvironmentObject private var model: AppModel
    let workout: YouTubeWorkout
    @State private var showingLog = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workout.displayTitle)
                .foregroundStyle(Theme.primaryText)
            HStack(spacing: 8) {
                if !workout.channel.isEmpty {
                    Text(workout.channel)
                }
                if let seconds = workout.durationSeconds {
                    Text("\(seconds / 60) min")
                }
                if workout.timesCompleted > 0 {
                    Text("done \(workout.timesCompleted)×")
                }
                if let rating = workout.rating {
                    Text("★ \(rating)")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 10) {
                if let url = workout.watchURL {
                    Link("Play", destination: url)
                        .buttonStyle(QuietButtonStyle())
                }
                Button("Log it") { showingLog = true }
                    .buttonStyle(QuietButtonStyle())
            }

            if !workout.chapters.isEmpty {
                DisclosureGroup("Chapters") {
                    ForEach(workout.chapters) { chapter in
                        Text("\(chapter.timestamp)  \(chapter.title)")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingLog) {
            LogSessionView(source: .youtube(workout.videoID), youtube: workout)
        }
    }
}

/// Pasting a link always works. Fetching the title needs an API key, and its
/// absence is stated plainly rather than hidden behind a spinner that fails.
struct AddYouTubeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var link = ""
    @State private var title = ""
    @State private var channel = ""
    @State private var style: TrainingStyle = .conditioning
    @State private var isFetching = false
    @State private var fetchNote: String?

    private var parsed: YouTubeLink? { YouTubeLinkParser.parse(link) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    TextField("Paste a YouTube URL", text: $link)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: link) { _, _ in Task { await fetchMetadata() } }

                    if let parsed, let videoID = parsed.videoID {
                        Text("Video \(videoID)")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    } else if !link.isEmpty {
                        Text("Not a YouTube link yet.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Channel", text: $channel)
                    Picker("Style", selection: $style) {
                        ForEach(TrainingStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    if isFetching { ProgressView() }
                    if let fetchNote {
                        Text(fetchNote)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .navigationTitle("Add a video")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(parsed?.videoID == nil)
                }
            }
        }
    }

    private func fetchMetadata() async {
        guard let videoID = parsed?.videoID, title.isEmpty else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            let metadata = try await YouTubeMetadataService.shared.metadata(for: videoID)
            title = metadata.title
            channel = metadata.channel
            fetchNote = nil
        } catch YouTubeMetadataError.noAPIKey {
            fetchNote = "No YouTube API key set, so titles stay manual. Everything else works."
        } catch {
            fetchNote = "Couldn't fetch the title. Type it in — the link still works."
        }
    }

    private func save() {
        guard let videoID = parsed?.videoID else { return }
        let workout = YouTubeWorkout(
            videoID: videoID,
            title: title,
            channel: channel,
            style: style,
            startSeconds: parsed?.startSeconds
        )
        model.edit { $0.youtubeWorkouts.append(workout) }
        dismiss()
    }
}
