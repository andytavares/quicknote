import QuicknoteKit
import SwiftUI

/// Types, places and projects (S10). Daily Brief opens its own window instead of selecting.
struct LibrarySidebar: View {
    @Bindable var model: LibraryModel
    @State private var projectEdit: ProjectEdit?
    @State private var projectName = ""
    @State private var projectToDelete: Project?

    var body: some View {
        List(selection: selection) {
            row(.brief)
            ForEach(LibrarySection.typeSections, id: \.self, content: row)
            Section("Places") { row(.sites) }
            Section("Projects") {
                ForEach(model.projects) { project in projectRow(project) }
                Button("+ New project") { beginEdit(.create) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("New project")
            }
            Section { row(.completed) }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        .alert(alertTitle, isPresented: isEditingProject) {
            TextField("Name", text: $projectName)
            Button("Save", action: saveProject)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete \(projectToDelete?.name ?? "project")?", isPresented: isDeletingProject, titleVisibility: .visible
        ) {
            Button("Delete project", role: .destructive) { projectToDelete.map(model.delete) }
        } message: {
            Text("Its notes are kept.")
        }
    }

    private var selection: Binding<LibrarySection?> {
        Binding(
            get: { model.section },
            set: { newValue in
                guard let newValue else { return }
                if newValue == .brief { BriefFeature.show() } else { model.section = newValue }
            })
    }

    private func row(_ section: LibrarySection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .badge(model.counts[section] ?? 0)
            .tag(section)
            .accessibilityLabel(section.title)
    }

    private func projectRow(_ project: Project) -> some View {
        let section = LibrarySection.project(project.id ?? 0)
        return Label {
            Text(project.name)
        } icon: {
            Image(systemName: "circle.fill").foregroundStyle(Color(hex: project.color))
        }
        .badge(model.counts[section] ?? 0)
        .tag(section)
        .accessibilityLabel("Project \(project.name)")
        .contextMenu {
            Button("Rename…") { beginEdit(.rename(project)) }
            Button("Delete…", role: .destructive) { projectToDelete = project }
        }
    }

    private func beginEdit(_ edit: ProjectEdit) {
        if case .rename(let project) = edit { projectName = project.name } else { projectName = "" }
        projectEdit = edit
    }

    private func saveProject() {
        let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let edit = projectEdit else { return }
        switch edit {
        case .create: model.createProject(named: name)
        case .rename(let project): model.rename(project, to: name)
        }
    }

    private var alertTitle: String {
        if case .rename = projectEdit { "Rename project" } else { "New project" }
    }

    private var isEditingProject: Binding<Bool> {
        Binding(get: { projectEdit != nil }, set: { if !$0 { projectEdit = nil } })
    }

    private var isDeletingProject: Binding<Bool> {
        Binding(get: { projectToDelete != nil }, set: { if !$0 { projectToDelete = nil } })
    }
}
