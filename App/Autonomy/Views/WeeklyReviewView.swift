import SwiftUI
import AutonomyKit

/// Questions first, numbers second, and the numbers are context rather than a
/// verdict. Nothing here is scored.
struct WeeklyReviewView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let weekStart: Date

    @State private var answers: [String: String] = [:]
    @State private var sustainability = 3
    @State private var adjustment = ""
    @State private var adjustments: [String] = []

    var body: some View {
        Form {
            Section {
                Text(weekLabel)
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Text(weekSummary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            ForEach(ReflectionPrompt.standard) { prompt in
                Section(prompt.question) {
                    TextField("", text: binding(for: prompt.id), axis: .vertical)
                        .lineLimit(2...6)
                    if !prompt.hint.isEmpty {
                        Text(prompt.hint)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            Section("Could you repeat this week for a year?") {
                Picker("Sustainability", selection: $sustainability) {
                    ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Changes you're making yourself") {
                ForEach(adjustments, id: \.self) { Text($0) }
                    .onDelete { adjustments.remove(atOffsets: $0) }
                HStack {
                    TextField("e.g. drop the third day while travelling", text: $adjustment)
                    Button("Add") {
                        let trimmed = adjustment.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        adjustments.append(trimmed)
                        adjustment = ""
                    }
                }
            }

            Section {
                Button("Save review") { save() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Weekly review")
        .onAppear(perform: load)
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { answers[id] ?? "" },
            set: { answers[id] = $0 }
        )
    }

    private var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: end))"
    }

    private var weekSummary: String {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let sessions = model.data.sessions.filter { $0.date >= weekStart && $0.date < end }
        let adjusted = sessions.filter(\.deviatedFromPlan).count
        guard !sessions.isEmpty else { return "No sessions logged. Weeks like that happen." }
        return "\(sessions.count) session\(sessions.count == 1 ? "" : "s")"
            + (adjusted > 0 ? ", \(adjusted) you adjusted yourself." : ".")
    }

    private func load() {
        guard let existing = model.data.reviews.first(where: {
            Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart)
        }) else { return }
        answers = existing.answers
        sustainability = existing.sustainabilityRating ?? 3
        adjustments = existing.selfDirectedAdjustments
    }

    private func save() {
        let review = WeeklyReview(
            weekStart: weekStart,
            answers: answers,
            sustainabilityRating: sustainability,
            selfDirectedAdjustments: adjustments,
            completedAt: Date()
        )
        model.edit { data in
            data.reviews.removeAll { Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) }
            data.reviews.append(review)
        }
        dismiss()
    }
}

/// The daily subjective check-in — three taps, no obligation.
struct CheckInView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var energy = 3
    @State private var stress = 3
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Energy") {
                    Picker("Energy", selection: $energy) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Stress") {
                    Picker("Stress", selection: $stress) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Anything else") {
                    TextField("Optional", text: $note, axis: .vertical)
                }
                Section {
                    Text("Your read counts alongside the wearables, not beneath them.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .navigationTitle("Check in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Skip") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.logCheckIn(energy: energy, stress: stress, note: note)
                        dismiss()
                    }
                }
            }
        }
    }
}
