import SwiftUI
import UniformTypeIdentifiers
import AutonomyKit

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var isSharing = false

    var body: some View {
        Form {
            Section("You") {
                Text(model.data.profile.displayName.isEmpty ? "No name set" : model.data.profile.displayName)
                    .foregroundStyle(Theme.primaryText)
                ForEach(model.data.profile.goals, id: \.self) { goal in
                    Text(goal.displayName).foregroundStyle(Theme.secondaryText)
                }
                NavigationLink("Edit") { OnboardingView(isEditing: true) }
            }

            Section("Connected") {
                let tools = model.connectedTools()
                if tools.isEmpty {
                    Text("Nothing connected. The app works fully without any of it.")
                        .foregroundStyle(Theme.secondaryText)
                }
                ForEach(tools, id: \.self) { tool in
                    Text(tool.rawValue.capitalized).foregroundStyle(Theme.primaryText)
                }
                Button(model.isSyncing ? "Syncing…" : "Sync now") {
                    Task { await model.sync() }
                }
                .disabled(model.isSyncing)
                if let error = model.syncError {
                    Text(error).font(.caption).foregroundStyle(Theme.warm)
                }
            }

            Section("Reminders") {
                Toggle(
                    "Recovery and workout reminders",
                    isOn: Binding(
                        get: { model.data.profile.remindersEnabled },
                        set: { newValue in model.edit { $0.profile.remindersEnabled = newValue } }
                    )
                )
                Text("Off by default, and they stay off unless you turn them on here.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Section("Your data") {
                Button("Export everything") { export() }
                if let exportURL {
                    ShareLink(item: exportURL) { Text("Share export") }
                }
                if let exportError {
                    Text(exportError).font(.caption).foregroundStyle(Theme.warm)
                }
                Text("JSON plus CSVs, readable without this app. No account, no analytics, nothing leaves the phone unless you send it.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
    }

    private func export() {
        do {
            let bundle = try model.exportBundle()
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("autonomy-export-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, contents) in bundle.files {
                try contents.write(to: directory.appendingPathComponent(name))
            }
            exportURL = directory
            exportError = nil
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
        }
    }
}

/// Short by design: goals, style, what you already use, and what your life
/// actually looks like. Everything is editable later and nothing is required.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var isEditing = false

    @State private var name = ""
    @State private var goals: Set<Goal> = []
    @State private var styles: Set<TrainingStyle> = []
    @State private var tools: Set<ConnectedTool> = []
    @State private var sessionsPerWeek = 3
    @State private var constraint = ""
    @State private var constraints: [String] = []

    var body: some View {
        Form {
            Section("Name") {
                TextField("What should the app call you?", text: $name)
            }

            Section("What are you actually after?") {
                ForEach(Goal.allCases, id: \.self) { goal in
                    toggleRow(goal.displayName, isOn: goals.contains(goal)) {
                        toggle(goal, in: &goals)
                    }
                }
            }

            Section("How do you like to train?") {
                ForEach(TrainingStyle.allCases, id: \.self) { style in
                    toggleRow(style.displayName, isOn: styles.contains(style)) {
                        toggle(style, in: &styles)
                    }
                }
            }

            Section("What do you already use?") {
                ForEach([ConnectedTool.appleHealth, .appleWatch, .whoop, .garmin, .oura, .strava], id: \.self) { tool in
                    toggleRow(tool.rawValue.capitalized, isOn: tools.contains(tool)) {
                        toggle(tool, in: &tools)
                    }
                }
            }

            Section("Realistically, how many sessions a week?") {
                Stepper("\(sessionsPerWeek) per week", value: $sessionsPerWeek, in: 1...7)
                Text("Pick the number you'd hit in a bad month, not a good one.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Section("Anything the app should work around?") {
                ForEach(constraints, id: \.self) { Text($0) }
                    .onDelete { constraints.remove(atOffsets: $0) }
                HStack {
                    TextField("travel, family meals, shift work…", text: $constraint)
                    Button("Add") {
                        let trimmed = constraint.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        constraints.append(trimmed)
                        constraint = ""
                    }
                }
            }

            Section {
                Button(isEditing ? "Save" : "Start") { save() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(isEditing ? "Your setup" : "Welcome")
        .onAppear(perform: load)
    }

    private func toggleRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(Theme.primaryText)
                Spacer()
                if isOn { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
            }
        }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func load() {
        let profile = model.data.profile
        name = profile.displayName
        goals = Set(profile.goals)
        styles = Set(profile.preferredStyles)
        tools = Set(profile.connectedTools)
        sessionsPerWeek = profile.targetSessionsPerWeek
        constraints = profile.constraints.map(\.label)
    }

    private func save() {
        model.edit { data in
            data.profile.displayName = name
            data.profile.goals = Array(goals)
            data.profile.preferredStyles = Array(styles)
            data.profile.connectedTools = Array(tools)
            data.profile.targetSessionsPerWeek = sessionsPerWeek
            data.profile.constraints = constraints.map { LifestyleConstraint(label: $0) }
        }
        dismiss()
    }
}
