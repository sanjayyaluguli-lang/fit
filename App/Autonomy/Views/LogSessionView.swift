import SwiftUI
import AutonomyKit

/// One flow for every kind of session: barbell work, a YouTube follow-along, a
/// walk you decided counted. Sets are optional — a title and a feeling is a
/// complete log.
struct LogSessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let source: SessionSource
    var plan: WorkoutPlan?
    var youtube: YouTubeWorkout?

    @State private var title = ""
    @State private var style: TrainingStyle = .hybrid
    @State private var minutes = ""
    @State private var feel: SessionFeel?
    @State private var rating: Int?
    @State private var notes = ""
    @State private var deviated = false
    @State private var rows: [SetRow] = []
    @State private var records: [PersonalRecord] = []

    struct SetRow: Identifiable {
        let id = UUID()
        var exerciseID: UUID
        var reps: String = ""
        var weight: String = ""
        var rpe: Double?
        var isWarmup = false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What did you do?", text: $title)
                    Picker("Style", selection: $style) {
                        ForEach(TrainingStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    TextField("Minutes", text: $minutes)
                        .keyboardType(.numberPad)
                }

                Section("How did it feel?") {
                    Picker("Feel", selection: $feel) {
                        Text("—").tag(SessionFeel?.none)
                        ForEach(SessionFeel.allCases, id: \.self) {
                            Text($0.displayName).tag(SessionFeel?.some($0))
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("I changed the plan today", isOn: $deviated)
                    if deviated {
                        Text("Good. That's the skill this app is trying to make unnecessary to teach.")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                }

                if youtube != nil {
                    Section("Rate it") {
                        Picker("Rating", selection: $rating) {
                            Text("—").tag(Int?.none)
                            ForEach(1...5, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                        }
                        .pickerStyle(.segmented)
                        Text("So you can find the good ones again.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Section("Sets (optional)") {
                    ForEach($rows) { $row in
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("Exercise", selection: $row.exerciseID) {
                                ForEach(model.data.exercises) { Text($0.name).tag($0.id) }
                            }
                            HStack {
                                TextField("Reps", text: $row.reps).keyboardType(.numberPad)
                                TextField("kg", text: $row.weight).keyboardType(.decimalPad)
                                Toggle("Warm-up", isOn: $row.isWarmup).labelsHidden()
                            }
                        }
                    }
                    .onDelete { rows.remove(atOffsets: $0) }

                    Button("Add set") { addRow() }
                }

                Section("Notes") {
                    TextField("Anything worth remembering", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("Log session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear(perform: prefill)
            .alert("New best", isPresented: .constant(!records.isEmpty)) {
                Button("Nice") { records = []; dismiss() }
            } message: {
                Text(records.map(describe).joined(separator: "\n"))
            }
        }
    }

    private func prefill() {
        if let plan {
            title = plan.name
            style = plan.style
            rows = plan.plannedExercises.map { SetRow(exerciseID: $0.exerciseID) }
        } else if let youtube {
            title = youtube.displayTitle
            style = youtube.style
            if let seconds = youtube.durationSeconds { minutes = String(seconds / 60) }
        }
    }

    private func addRow() {
        let fallback = rows.last?.exerciseID ?? model.data.exercises.first?.id
        guard let exerciseID = fallback else { return }
        rows.append(SetRow(exerciseID: exerciseID))
    }

    private func save() {
        let sets: [SetLog] = rows.enumerated().compactMap { index, row in
            let reps = Int(row.reps)
            let weight = Double(row.weight.replacingOccurrences(of: ",", with: "."))
            guard reps != nil || weight != nil else { return nil }
            return SetLog(
                exerciseID: row.exerciseID,
                setIndex: index + 1,
                reps: reps,
                weightKg: weight,
                rpe: row.rpe.flatMap(RPE.init),
                isWarmup: row.isWarmup
            )
        }

        let session = WorkoutSession(
            date: Date(),
            source: source,
            title: title.isEmpty ? "Session" : title,
            style: style,
            durationMinutes: Int(minutes),
            sets: sets,
            feel: feel,
            rating: rating,
            notes: notes,
            deviatedFromPlan: deviated
        )

        let newRecords = model.newRecords(for: session)
        model.log(session)

        if newRecords.isEmpty {
            dismiss()
        } else {
            records = newRecords
        }
    }

    private func describe(_ record: PersonalRecord) -> String {
        let name = model.data.exercise(record.exerciseID)?.name ?? "that lift"
        let weight = record.weightKg == record.weightKg.rounded()
            ? String(Int(record.weightKg))
            : String(format: "%.1f", record.weightKg)
        return "\(name): \(weight) kg × \(record.reps)"
    }
}
