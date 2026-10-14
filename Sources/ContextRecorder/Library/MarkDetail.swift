import SwiftUI

/// Everything about one mark. The top answers "what is this": title, when and where, the note and the
/// picture. Below it, folding sections hold what was said and the page detail, most useful first.
struct MarkDetail: View {
    var model: SessionModel
    var mark: SessionMark
    var collapse: () -> Void
    @State private var copied = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            NoteEditor(model: model, mark: mark)
            images
            if let n = MarkText.narration(mark.narration) {
                InspectorSection("narration", title: "What was said", symbol: "waveform") {
                    NarrationText(narration: n)
                }
            }
            if let b = mark.browser { PageContext(model: model, snapshot: b) }
            ContextBlock(context: mark.context)
        }
        .confirmationDialog("Delete mark \(mark.index)?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await model.deleteReviewMark(mark.index) } }
        } message: {
            Text("Its screenshot and Markdown are removed from the session folder.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MarkGlyph(mark: mark, size: 22)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                Text(MarkText.title(mark))
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Spacer(minLength: 4)
                IconButton(symbol: "chevron.up", help: "Collapse", action: collapse)
            }
            HStack(spacing: 6) {
                Text(mark.isShot ? "Shot" : "Mark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(mark.isShot ? Color.shot : Color.mark)
                if mark.isReview {
                    Text("Review")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(.quaternary, in: .capsule)
                        .help("Taken from the video afterwards: no live page snapshot")
                }
                MarkMeta(model: model, mark: mark)
            }
            .padding(.leading, 30)
            HStack(spacing: 0) {
                IconButton(symbol: "play.fill", help: "Play from 5 seconds before") { model.playFromBefore(mark) }
                IconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: "Copy as Markdown") {
                    copy(model.markdown(for: mark))
                    withAnimation { copied = true }
                    Task { try? await Task.sleep(for: .seconds(1.4)); withAnimation { copied = false } }
                }
                if let url = model.url(mark.image) {
                    IconButton(symbol: "folder", help: "Reveal image in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                if mark.isReview {
                    IconButton(symbol: "trash", help: "Delete this mark") { confirmDelete = true }
                }
            }
            .padding(.leading, 24)
        }
    }

    /// The shot, with the full frame as a small inset: a region shot is cropped, and the frame shows what
    /// else was on screen.
    @ViewBuilder private var images: some View {
        if let url = model.url(mark.image) {
            MarkImage(url: url, label: "Mark \(mark.index) image", annotated: mark.imageAnnotated, revision: model.annotationRevision) { model.view(mark.originalImage) }
                .overlay(alignment: .bottomLeading) {
                    if mark.isShot, let frame = model.url(mark.frame), mark.frame != mark.image,
                       FileManager.default.fileExists(atPath: frame.path) {
                        MarkImage(url: frame, label: "Full screen frame for mark \(mark.index)", compact: true, annotated: mark.frameAnnotated, revision: model.annotationRevision) { model.view(mark.originalFrame) }
                            .frame(width: 92)
                            .overlay(alignment: .bottom) {
                                Text("Full screen")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(.black.opacity(0.55), in: .capsule)
                                    .padding(4)
                                    .allowsHitTesting(false)
                            }
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                            .padding(8)
                            .help("What else was on screen at this moment")
                    }
                }
        }
    }
}

struct MarkImage: View {
    var url: URL
    var label: String
    var compact = false
    /// Drawn on in the image viewer: shows a small badge.
    var annotated = false
    /// SessionModel.annotationRevision: reload when annotations are saved.
    var revision = 0
    var open: () -> Void
    @State private var image: NSImage?
    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            ZStack {
                if let image {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    Rectangle().fill(.quaternary).aspectRatio(16 / 10, contentMode: .fit)
                }
            }
            .background(Color.stage.opacity(0.5))
            .clipShape(.rect(cornerRadius: compact ? 6 : 9))
            .overlay(RoundedRectangle(cornerRadius: compact ? 6 : 9).strokeBorder(.separator.opacity(0.7), lineWidth: 0.5))
            .overlay(alignment: .topTrailing) {
                if annotated {
                    Image(systemName: "pencil.tip.crop.circle.fill")
                        .font(.system(size: compact ? 11 : 14, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(compact ? 3 : 6)
                        .help("Annotated in the image viewer")
                        .accessibilityLabel("Annotated")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !compact {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .glassEffect(.regular, in: .circle)
                        .padding(7)
                        .opacity(hovering ? 1 : 0)
                }
            }
            .shadow(color: .black.opacity(compact ? 0 : 0.08), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .help("View image")
        .accessibilityLabel(label)
        .accessibilityHint("Opens the image viewer")
        .task(id: "\(url.path)#\(revision)") { image = await ImageCache.shared.image(url, maxPixel: compact ? 400 : 1400) }
    }
}

/// The sentence at the mark at full weight, the rest dimmed, with a small flag where the mark landed.
struct NarrationText: View {
    var narration: MarkText.Narration

    var body: some View {
        let marker = Text(" \(Image(systemName: "flag.fill")) ").font(.system(size: 9)).foregroundStyle(Color.mark).baselineOffset(1)
        let before = narration.before.joined(separator: " ")
        let after = narration.after.joined(separator: " ")
        let lead = MarkText.withoutFlag(narration.focusLead)
        let tail = MarkText.withoutFlag(narration.focusTail)
        let dim = Color.secondary.opacity(0.85)
        let text: Text = Text("\(Text(before.isEmpty ? "" : before + " ").foregroundStyle(dim))\(Text(lead).foregroundStyle(.primary).fontWeight(.medium))\(marker)\(Text(tail).foregroundStyle(.primary).fontWeight(.medium))\(Text(after.isEmpty ? "" : " " + after).foregroundStyle(dim))")
        text
            .font(.system(size: 13))
            .lineSpacing(3)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Narration: \(narration.focus)")
    }
}

struct ContextBlock: View {
    var context: MarkContext?

    var body: some View {
        if let c = context {
            let rows: [(String, String?)] = [
                ("Window", c.windowTitle.nonEmpty),
                ("Page", c.browserTitle != c.windowTitle ? c.browserTitle.nonEmpty : nil),
            ].filter { $0.1 != nil }
            InspectorSection("window", title: "Window", symbol: "macwindow", open: false) { GroupBlock {
                GroupRow(divider: !rows.isEmpty || c.browserURL.nonEmpty != nil) {
                    HStack(spacing: 8) {
                        AppIcon(bundleID: c.bundleID, size: 18)
                        Text(c.appName ?? "Unknown app").font(.system(size: 13, weight: .medium))
                        Spacer()
                        if let id = c.bundleID { Text(id).font(.system(size: 10.5).monospaced()).foregroundStyle(.tertiary).lineLimit(1) }
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    GroupRow(divider: i < rows.count - 1 || c.browserURL.nonEmpty != nil) {
                        KeyValue(key: row.0) { Text(row.1 ?? "").textSelection(.enabled) }
                    }
                }
                if let u = c.browserURL.nonEmpty {
                    GroupRow(divider: false) {
                        KeyValue(key: "URL") {
                            if let url = URL(string: u) { Link(u, destination: url) } else { Text(u) }
                        }
                    }
                }
            } }
        }
    }
}

struct KeyValue<Value: View>: View {
    var key: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(key).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
            value.font(.system(size: 12.5)).lineLimit(3)
        }
    }
}

// MARK: Page context

/// Problems first (they're usually why you marked), then the element under the pointer, the region's
/// elements, focus, and the saved page.
struct PageContext: View {
    var model: SessionModel
    var snapshot: PageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let error = snapshot.error {
                Label("Page snapshot unavailable: \(error)", systemImage: "exclamationmark.circle")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            let problems = Array((snapshot.recent ?? []).filter(\.isProblem).suffix(8))
            if !problems.isEmpty {
                InspectorSection("problems", title: "Recent problems", symbol: "exclamationmark.triangle.fill", tint: .red,
                                 trailing: "\(problems.count)") {
                    GroupBlock {
                        ForEach(Array(problems.enumerated()), id: \.offset) { i, e in
                            GroupRow(divider: i < problems.count - 1) { PageEventRow(event: e) }
                        }
                    }
                }
            }
            if let h = snapshot.hovered {
                InspectorSection("pointer", title: "Under pointer", symbol: "cursorarrow.rays") {
                    GroupBlock { ElementView(element: h, full: true).padding(10) }
                }
            }
            if let region = snapshot.region {
                if let els = region.elements, !els.isEmpty {
                    let shown = Array(els.prefix(15))
                    InspectorSection("region", title: "Elements in region", symbol: "rectangle.dashed",
                                     trailing: "\(els.count)", open: false) {
                        GroupBlock {
                            ForEach(Array(shown.enumerated()), id: \.offset) { i, el in
                                GroupRow(divider: i < shown.count - 1) { ElementView(element: el, full: false, compact: true) }
                            }
                        }
                    }
                } else if let note = region.note {
                    Label("Region: \(note)", systemImage: "rectangle.dashed").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if snapshot.focused != nil || snapshot.selection.nonEmpty != nil {
                InspectorSection("focus", title: "Focus and selection", symbol: "character.cursor.ibeam", open: false) {
                    GroupBlock {
                        if let f = snapshot.focused {
                            GroupRow(divider: snapshot.selection.nonEmpty != nil) { ElementView(element: f, full: false) }
                        }
                        if let s = snapshot.selection.nonEmpty {
                            GroupRow(divider: false) {
                                KeyValue(key: "Selected") { Text("“\(s)”").textSelection(.enabled) }
                            }
                        }
                    }
                }
            }
            if let page = model.url(snapshot.pageFile) {
                Button { openInChrome(page) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.richtext").font(.system(size: 16)).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Open saved page").font(.system(size: 12.5, weight: .medium))
                            Text("The DOM as it was at the mark, in Chrome").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(.background.opacity(0.7), in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(page.path)
            } else if let err = snapshot.pageError {
                Label("Saved page missing: \(err)", systemImage: "doc.badge.ellipsis")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    /// Safari can't render MHTML; Chrome can.
    private func openInChrome(_ url: URL) {
        if let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            NSWorkspace.shared.open([url], withApplicationAt: chrome, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Selector, text, component breadcrumbs, props and source location for one element.
struct ElementView: View {
    var element: PageElement
    var full: Bool
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let t = element.text.nonEmpty, !compact {
                Text("“\(t)”").font(.system(size: 13, weight: .medium)).lineLimit(3).textSelection(.enabled)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(element.selector ?? element.tag ?? "element")
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.quaternary.opacity(0.7), in: .rect(cornerRadius: 4))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                if compact, let t = element.text.nonEmpty {
                    Text("“\(String(t.prefix(80)))”").font(.system(size: 12)).lineLimit(1)
                }
            }
            if !element.componentPath.isEmpty, !compact || full {
                Breadcrumbs(items: element.componentPath)
            }
            if full, let p = element.props, let comp = p.component {
                PropsView(component: comp, props: p.props ?? [:])
            }
            if let src = element.source, src.location != nil { SourceButton(source: src) }
        }
    }
}

/// `<SaveButton>` with its props as a small key/value table.
struct PropsView: View {
    var component: String
    var props: [String: JSONValue]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("<\(component)>").font(.system(size: 11, weight: .semibold).monospaced()).foregroundStyle(.secondary)
            if props.isEmpty {
                Text("no props").font(.system(size: 11)).foregroundStyle(.tertiary)
            } else {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 2) {
                    ForEach(props.sorted { $0.key < $1.key }, id: \.key) { key, value in
                        GridRow {
                            Text(key).foregroundStyle(.secondary)
                            Text(value.jsonText).foregroundStyle(valueColor(value)).lineLimit(2).textSelection(.enabled)
                        }
                    }
                }
                .font(.system(size: 11).monospaced())
                .padding(.leading, 10)
            }
        }
    }

    private func valueColor(_ v: JSONValue) -> Color {
        switch v {
        case .string: return .primary
        case .number, .bool: return .purple
        default: return .secondary
        }
    }
}

struct Breadcrumbs: View {
    var items: [String]
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "square.stack.3d.up").font(.system(size: 9)).foregroundStyle(.tertiary)
            ForEach(Array(items.enumerated()), id: \.offset) { i, name in
                if i > 0 { Image(systemName: "chevron.compact.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.quaternary) }
                Text(name)
                    .font(.system(size: 11, weight: i == items.count - 1 ? .semibold : .regular))
                    .foregroundStyle(i == items.count - 1 ? .primary : .secondary)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Components: " + items.joined(separator: ", "))
    }
}

/// `file:line` that opens in the editor when the file exists on this Mac; otherwise it copies.
struct SourceButton: View {
    var source: SourceLocation
    @State private var copied = false

    var body: some View {
        let loc = source.location ?? ""
        let exists = source.file.map { FileManager.default.fileExists(atPath: $0) } ?? false
        HStack(spacing: 6) {
            Button {
                if exists, let file = source.file, let url = URL(string: "vscode://file\(file):\(source.line ?? 1):\(source.column ?? 1)") {
                    NSWorkspace.shared.open(url)
                } else {
                    copy(loc)
                    withAnimation { copied = true }
                    Task { try? await Task.sleep(for: .seconds(1.2)); withAnimation { copied = false } }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: copied ? "checkmark" : (exists ? "arrow.up.forward.app" : "chevron.left.forwardslash.chevron.right"))
                        .font(.system(size: 10, weight: .semibold))
                    Text(loc).font(.system(size: 11).monospaced()).lineLimit(1).truncationMode(.head)
                }
                .foregroundStyle(.tint)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help(exists ? "Open in editor" : "Copy path (the file isn't at this path on this Mac)")
            if source.isPostTransform {
                Text("post-transform line")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .overlay(Capsule().strokeBorder(.quaternary))
                    .help("React 19 stacks point at the transformed module, so the line can be off.")
            }
        }
    }
}

/// A typed note for the mark; its first line becomes the title. Saved on Return or when focus leaves.
struct NoteEditor: View {
    var model: SessionModel
    var mark: SessionMark
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(focused ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            TextField("Add a note…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...6)
                .focused($focused)
                .onSubmit { save() }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(.background.opacity(0.7), in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(focused ? AnyShapeStyle(.tint.opacity(0.6)) : AnyShapeStyle(.separator.opacity(0.6)),
                                                                lineWidth: focused ? 1.5 : 0.5))
        .onAppear {
            text = mark.note ?? ""
            if model.focusNoteFor == mark.index {
                model.focusNoteFor = nil
                DispatchQueue.main.async { focused = true }
            }
        }
        .onChange(of: mark.note) { _, note in if !focused || text.isEmpty { text = note ?? "" } }
        .onChange(of: focused) { _, isFocused in if !isFocused { save() } }
        .accessibilityLabel("Note for mark \(mark.index)")
    }

    private func save() {
        let note = text
        Task { await model.setNote(note, for: mark.index) }
    }
}
