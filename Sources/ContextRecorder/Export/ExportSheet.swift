import AppKit
import Observation
import SwiftUI

@MainActor @Observable
final class ExportSheetModel: Identifiable {
    let session: SessionModel
    var targets: [ExportTarget] = ExportTargets.load()
    var selected: ExportTarget?
    var projects: [Pgm.Project] = []
    var projectID: String?
    var newProjectName = ""
    var roots: [Pgm.Node] = []
    var parentID: String?
    var selectedMarks: Set<Int>
    var loading = false
    var error: String?
    var phase: Phase = .idle

    enum Phase: Equatable { case idle, running(String, Double), done(created: Int, updated: Int) }

    static let newProjectTag = "__new__"

    init(session: SessionModel) {
        self.session = session
        selectedMarks = Set(session.marks.map(\.index))
        if let first = targets.first { choose(first) }
    }

    var record: ExportRecord { ExportRecord.load(session.folder) }

    /// Marks already sent to the chosen grid project (they'll be updated, not duplicated).
    var exportedMarks: Set<Int> {
        guard let selected, let projectID, let d = record.destination(dataDir: selected.dataDir, project: projectID) else { return [] }
        return Set(d.marks.keys.compactMap(Int.init))
    }

    var canExport: Bool {
        guard selected != nil, !selectedMarks.isEmpty, !loading else { return false }
        if case .running = phase { return false }
        if projectID == Self.newProjectTag { return !newProjectName.trimmingCharacters(in: .whitespaces).isEmpty }
        return projectID != nil
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Use Folder"
        panel.message = "Choose a project folder. Its grid is stored in pgm/data inside it."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let target = targets.first { $0.folder == url.path } ?? ExportTarget(folder: url.path, lastUsed: .now)
        if !targets.contains(target) { targets.insert(target, at: 0) }
        choose(target)
    }

    func forget(_ target: ExportTarget) {
        ExportTargets.remove(target)
        targets.removeAll { $0 == target }
        if selected == target { selected = nil; projects = []; projectID = nil; roots = [] }
    }

    func choose(_ target: ExportTarget) {
        selected = target
        phase = .idle
        error = nil
        newProjectName = target.name
        Task { await loadProjects(preferring: target.projectID) }
    }

    func loadProjects(preferring preferred: String?) async {
        guard let target = selected else { return }
        loading = true
        defer { loading = false }
        do {
            projects = try await Pgm(dataDir: target.dataDir).projects()
            if let preferred, projects.contains(where: { $0.id == preferred }) { projectID = preferred }
            else { projectID = projects.first?.id ?? Self.newProjectTag }
            parentID = target.projectID == projectID ? target.parentNodeID : nil
            await loadRoots()
        } catch {
            projects = []
            projectID = nil
            self.error = error.localizedDescription
        }
    }

    func loadRoots() async {
        guard let target = selected, let projectID, projectID != Self.newProjectTag else { roots = []; return }
        roots = (try? await Pgm(dataDir: target.dataDir).rootNodes(project: projectID)) ?? []
        // The session nodes made by earlier exports aren't useful parents.
        let sessionNodes = Set(record.destinations.map(\.sessionNodeID))
        roots.removeAll { sessionNodes.contains($0.id) }
        if let parentID, !roots.contains(where: { $0.id == parentID }) { self.parentID = nil }
    }

    func export() async {
        guard var target = selected, let data = session.data else { return }
        error = nil
        phase = .running("Starting…", 0)
        do {
            var project = projectID
            if project == Self.newProjectTag {
                let created = try await Pgm(dataDir: target.dataDir).createProject(name: newProjectName.trimmingCharacters(in: .whitespaces))
                projects.append(created)
                project = created.id
                projectID = created.id
            }
            guard let project else { return }
            target.projectID = project
            target.projectName = projects.first { $0.id == project }?.name
            target.parentNodeID = parentID
            target.parentTitle = roots.first { $0.id == parentID }?.title
            target.lastUsed = .now
            let marks = session.marks.filter { selectedMarks.contains($0.index) }
            let exporter = PgmExporter(session: data, folder: session.folder, target: target, projectID: project, marks: marks)
            try await exporter.run { [weak self] step in
                switch step {
                case .progress(let label, let fraction): self?.phase = .running(label, fraction)
                case .done(let created, let updated): self?.phase = .done(created: created, updated: updated)
                }
            }
            ExportTargets.save(target)
            targets = ExportTargets.load()
            selected = target
        } catch {
            phase = .idle
            self.error = error.localizedDescription
        }
    }

    /// `pgm viewer` on the folder's grid; it opens the browser itself.
    func openGrid() {
        guard let target = selected else { return }
        Task {
            guard let env = try? await Pgm.environment() else { return }
            let p = Process()
            p.executableURL = env.pgm
            p.arguments = ["viewer", "--data-dir", target.dataDir.path]
            p.environment = env.variables
            p.currentDirectoryURL = target.url
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
        }
    }
}

struct ExportSheet: View {
    @Bindable var model: ExportSheetModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    folders
                    if model.selected != nil { grid }
                    marks
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 600, height: 640)
        .background(.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("Export to Product Grid").font(.system(size: 15, weight: .semibold))
                Text("\(SessionTitle.title(for: model.session.folder)) · one node for the session, one per mark")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }

    // MARK: Folders

    private var folders: some View {
        GroupBlock(title: "Project folder", symbol: "folder") {
            if model.targets.isEmpty {
                GroupRow {
                    Text("Choose the folder whose grid should get these marks. The grid lives in pgm/data inside it, next to your code.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            ForEach(model.targets) { t in
                GroupRow {
                    FolderRow(target: t, selected: model.selected == t) { model.choose(t) }
                        .contextMenu {
                            Button("Reveal in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([t.url]) }
                            Button("Forget Folder", systemImage: "minus.circle") { model.forget(t) }
                        }
                }
            }
            GroupRow(divider: false) {
                Button { model.addFolder() } label: {
                    Label("Add Folder…", systemImage: "plus").font(.system(size: 12.5, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
    }

    // MARK: Grid

    private var grid: some View {
        GroupBlock(title: "Grid", symbol: "square.grid.3x3") {
            if let error = model.error {
                GroupRow {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12)).foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            GroupRow {
                HStack {
                    Text("Project").font(.system(size: 12.5))
                    Spacer()
                    if model.loading { ProgressView().controlSize(.small) }
                    Picker("Project", selection: Binding(get: { model.projectID ?? "" }, set: { id in
                        model.projectID = id
                        Task { await model.loadRoots() }
                    })) {
                        ForEach(model.projects) { p in Text(p.name).tag(p.id) }
                        if !model.projects.isEmpty { Divider() }
                        Text("New Project…").tag(ExportSheetModel.newProjectTag)
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(model.loading)
                }
            }
            if model.projectID == ExportSheetModel.newProjectTag {
                GroupRow {
                    HStack {
                        Text("Name").font(.system(size: 12.5))
                        Spacer()
                        TextField("Project name", text: $model.newProjectName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                    }
                }
            }
            GroupRow(divider: false) {
                HStack {
                    Text("Put the session under").font(.system(size: 12.5))
                    Spacer()
                    Picker("Parent", selection: $model.parentID) {
                        Text("Top level").tag(String?.none)
                        if !model.roots.isEmpty { Divider() }
                        ForEach(model.roots) { n in Text(n.title).tag(Optional(n.id)) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(model.projectID == ExportSheetModel.newProjectTag || model.loading)
                }
            }
        }
    }

    // MARK: Marks

    private var marks: some View {
        let exported = model.exportedMarks
        let all = model.session.marks
        return GroupBlock(title: "Marks", symbol: "flag", trailing: "\(model.selectedMarks.count) of \(all.count)") {
            if all.isEmpty {
                GroupRow(divider: false) { Text("This session has no marks.").font(.system(size: 12)).foregroundStyle(.secondary) }
            }
            ForEach(Array(all.enumerated()), id: \.element.id) { i, m in
                GroupRow(divider: i < all.count - 1) {
                    Toggle(isOn: Binding(get: { model.selectedMarks.contains(m.index) }, set: { on in
                        if on { model.selectedMarks.insert(m.index) } else { model.selectedMarks.remove(m.index) }
                    })) {
                        HStack(spacing: 10) {
                            Thumbnail(url: model.session.url(m.image), maxPixel: 160)
                                .frame(width: 48, height: 30)
                                .clipShape(.rect(cornerRadius: 4))
                            MarkGlyph(mark: m, size: 18)
                            Text(MarkText.title(m)).font(.system(size: 12.5)).lineLimit(1)
                            Spacer(minLength: 6)
                            if exported.contains(m.index) {
                                Text("Update")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.quaternary, in: .capsule)
                                    .help("Sent before: its node gets the new context and images; edits made in the grid are kept.")
                            }
                            Text(Format.time(m.offsetSeconds)).font(.system(size: 11).monospacedDigit()).foregroundStyle(.tertiary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            switch model.phase {
            case .idle:
                if let selected = model.selected {
                    Text("Writes to \(abbreviate(selected.dataDir.path))")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            case .running(let label, let fraction):
                ProgressView(value: fraction).frame(width: 120)
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            case .done(let created, let updated):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(doneText(created: created, updated: updated)).font(.system(size: 12, weight: .medium))
            }
            Spacer()
            if case .done = model.phase {
                Button("Open Grid") { model.openGrid() }
                    .help("Runs pgm viewer on this folder's grid")
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            } else {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Export") { Task { await model.export() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canExport)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func doneText(created: Int, updated: Int) -> String {
        var bits: [String] = []
        if created > 0 { bits.append("\(created) new") }
        if updated > 0 { bits.append("\(updated) updated") }
        return "Exported " + (bits.isEmpty ? "the session" : bits.joined(separator: ", "))
    }
}

struct FolderRow: View {
    var target: ExportTarget
    var selected: Bool
    var choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                Image(nsImage: NSWorkspace.shared.icon(forFile: target.folder))
                    .resizable().frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(target.name).font(.system(size: 13, weight: .medium))
                    Text(abbreviate(target.folder)).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    if let p = target.projectName {
                        Text(p).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary)
                    }
                    Text(target.lastUsed, format: .relative(presentation: .named))
                        .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// `~/Projects/app` rather than `/Users/me/Projects/app`.
func abbreviate(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
}
