import SwiftUI
import AutonomyKit

/// Deliberately plain: name, a few exercises, sets and reps. A builder that
/// takes ten minutes to use doesn't get used.
struct PlanBuilderView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var style: TrainingStyle = .hybrid
    @State private var blockStyle: BlockStyle = .straight
    @State private var entries: [Entry] = []
    @State private var newExerciseName = ""

    struct Entry: Identifiable {
        let id = UUID()
        var exerciseID: UUID
        var sets: Int
        var reps: Int
        var rpe: Double?
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    TextField("Name", text: $name)
                    Picker("Style", selection: $style) {
                        ForEach(TrainingStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Structure", selection: $blockStyle) {
                        Text("Straight sets").tag(BlockStyle.straight)
                        Text("Superset").tag(BlockStyle.superset)
                        Text("Circuit").tag(BlockStyle.circuit)
                    }
                }

                Section("Exercises") {
                    ForEach($entries) { $entry in
                        VStack(alignment: .leading) {
                            Picker("Exercise", selection: $entry.exerciseID) {
                                ForEach(model.data.exercises) { Text($0.name).tag($0.id) }
                            }
                            Stepper("\(entry.sets) sets", value: $entry.sets, in: 1...10)
                            Stepper("\(entry.reps) reps", value: $entry.reps, in: 1...50)
                        }
                    }
                    .onDelete { entries.remove(atOffsets: $0) }

                    Button("Add exercise") {
                        guard let first = model.data.exercises.first else { return }
                        entries.append(Entry(exerciseID: first.id, sets: 3, reps: 8, rpe: 8))
                    }
                }

                Section("New exercise") {
                    HStack {
                        TextField("Name", text: $newExerciseName)
                        Button("Add") { addExercise() }
                            .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Text("Anything you actually do belongs here, however unusual.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .navigationTitle("New plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || entries.isEmpty)
                }
            }
        }
    }

    private func addExercise() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let exercise = Exercise(name: trimmed)
        model.edit { $0.exercises.append(exercise) }
        entries.append(Entry(exerciseID: exercise.id, sets: 3, reps: 8, rpe: 8))
        newExerciseName = ""
    }

    private func save() {
        let planned = entries.map { entry in
            PlannedExercise(
                exerciseID: entry.exerciseID,
                sets: (0..<entry.sets).map { _ in
                    PrescribedSet(reps: entry.reps, rpe: entry.rpe.flatMap(RPE.init), restSeconds: 120)
                }
            )
        }
        let plan = WorkoutPlan(
            name: name.trimmingCharacters(in: .whitespaces),
            style: style,
            blocks: [WorkoutBlock(title: name, style: blockStyle, exercises: planned)],
            isUserCreated: true
        )
        model.edit { $0.plans.append(plan) }
        dismiss()
    }
}
