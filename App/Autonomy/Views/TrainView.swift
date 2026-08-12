import SwiftUI
import AutonomyKit

/// The owner's own library first; templates are a small, clearly-labelled
/// section underneath. The ordering is the argument.
struct TrainView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingBuilder = false

    var body: some View {
        List {
            Section("Your plans") {
                if model.data.plans.filter(\.isUserCreated).isEmpty {
                    Text("Nothing here yet. A plan can be three lines.")
                        .foregroundStyle(Theme.secondaryText)
                }
                ForEach(model.data.plans.filter(\.isUserCreated)) { plan in
                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                        PlanRow(plan: plan)
                    }
                }
            }

            let derived = model.data.plans.filter { !$0.isUserCreated }
            if !derived.isEmpty {
                Section("From templates") {
                    ForEach(derived) { plan in
                        NavigationLink(destination: PlanDetailView(plan: plan)) {
                            PlanRow(plan: plan)
                        }
                    }
                }
            }

            Section("Starting points") {
                ForEach(PeriodizationTemplates.all()) { template in
                    Button {
                        add(template)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name).foregroundStyle(Theme.primaryText)
                            Text(template.summary)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                Text("Add one, then change it. Editing is what makes it yours.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Train")
        .toolbar {
            Button {
                showingBuilder = true
            } label: {
                Label("New plan", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingBuilder) { PlanBuilderView() }
    }

    private func add(_ template: PeriodizationTemplates.Template) {
        model.edit { data in
            data.plans.append(contentsOf: template.build(data.exercises))
        }
    }
}

struct PlanRow: View {
    let plan: WorkoutPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(plan.name).foregroundStyle(Theme.primaryText)
            Text("\(plan.style.displayName) · \(plan.plannedExercises.count) exercises")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

struct PlanDetailView: View {
    @EnvironmentObject private var model: AppModel
    @State var plan: WorkoutPlan
    @State private var showingLog = false

    var body: some View {
        List {
            ForEach(plan.blocks) { block in
                Section(block.title.isEmpty ? block.style.rawValue.capitalized : block.title) {
                    ForEach(block.exercises) { planned in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.data.exercise(planned.exerciseID)?.name ?? "Unknown exercise")
                                .foregroundStyle(Theme.primaryText)
                            Text(describe(planned))
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                            if let suggestion = ProgressiveOverload.suggestion(
                                for: planned.exerciseID,
                                in: model.data.sessions
                            ) {
                                Text(suggestion.rationale)
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Log this session") { showingLog = true }
                Text("Change anything you like before or during it — mark the session as adjusted when you do.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(plan.name)
        .sheet(isPresented: $showingLog) {
            LogSessionView(source: .plan(plan.id), plan: plan)
        }
    }

    private func describe(_ planned: PlannedExercise) -> String {
        let sets = planned.sets.count
        guard let first = planned.sets.first else { return "\(sets) sets" }
        var parts = ["\(sets) ×"]
        if let reps = first.reps {
            parts.append(first.repRangeUpper.map { "\(reps)–\($0)" } ?? "\(reps)")
        }
        if let rpe = first.rpe { parts.append("@ RPE \(rpe.value)") }
        if let rest = first.restSeconds { parts.append("· \(rest / 60)m rest") }
        return parts.joined(separator: " ")
    }
}
