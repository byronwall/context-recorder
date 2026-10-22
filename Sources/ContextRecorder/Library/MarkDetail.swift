import SwiftUI

/// Everything about one mark, laid out flat in the list. The top answers "what is this": title, when
/// and where, actions, the note and the picture. Below it, folding sections hold what was said and the
/// page detail, most useful first.
struct MarkDetail: View {
    var model: SessionModel
    var mark: SessionMark
    var collapse: () -> Void
    @State private var copied = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            NoteEditor(model: model, mark: mark)
            images
            VStack(alignment: .leading, spacing: 12) {
                if let n = MarkText.narration(mark.narration) {
                    InspectorSection("narration", title: "Said") { NarrationText(narration: n) }
                }
                if let b = mark.browser { PageContext(model: model, snapshot: b) }
                ContextBlock(context: mark.context)
            }
            .padding(.top, 4)
        }
        .confirmationDialog("Delete mark \(mark.index)?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await model.deleteReviewMark(mark.index) } }
        } message: {
            Text("Its screenshot and Markdown are removed from the session folder.")
        }
    }

    /// Glyph, title and meta collapse the mark when clicked; the actions sit on the title's first line.
    private var header: some View {
        HStack(alignment: .top, spacing: 4) {
            Button(action: collapse) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    MarkGlyph(mark: mark, size: 20)
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Highlight.text(MarkText.title(mark), model.query))
                            .font(.system(size: 14, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        MarkMeta(model: model, mark: mark, showKind: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Collapse")
            .accessibilityLabel("\(mark.isShot ? "Shot" : "Mark") \(mark.index): \(MarkText.title(mark))")
            .accessibilityHint("Collapses the mark")
            HStack(spacing: 0) {
                IconButton(symbol: "play.fill", help: "Play from 5 seconds before") { model.playFromBefore(mark) }
                IconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: "Copy as Markdown") {
                    copy(model.markdown(for: mark))
                    withAnimation { copied = true }
                    Task { try? await Task.sleep(for: .seconds(1.4)); withAnimation { copied = false } }
                }
                .contentTransition(.symbolEffect(.replace))
                moreMenu
            }
            .offset(y: -3)
        }
    }

    private var moreMenu: some View {
        Menu {
            if let url = model.url(mark.image) {
                Button("View Image", systemImage: "eye") { model.view(mark.originalImage) }
                Button("Reveal Image in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            if let page = model.url(mark.browser?.pageFile) {
                Button("Open Saved Page in Chrome", systemImage: "doc.richtext") { PageContext.openInChrome(page) }
            }
            if mark.isReview {
                Divider()
                Button("Delete Mark…", systemImage: "trash", role: .destructive) { confirmDelete = true }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 24)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .foregroundStyle(.secondary)
        .fixedSize()
        .help("More")
    }

    /// The shot at its own shape, capped in height so a tall capture stays a column. A region shot
    /// also shows the full frame beside it: what else was on screen.
    @ViewBuilder private var images: some View {
        if let url = model.url(mark.image) {
            HStack(alignment: .top, spacing: 10) {
                FitBox(aspect: ImageAspect.of(url, revision: model.annotationRevision), maxHeight: 220) {
                    MarkImage(url: url, label: "Mark \(mark.index) image", annotated: mark.imageAnnotated, revision: model.annotationRevision) { model.view(mark.originalImage) }
                }
                if mark.isShot, let frame = model.url(mark.frame), mark.frame != mark.image,
                   FileManager.default.fileExists(atPath: frame.path) {
                    VStack(alignment: .leading, spacing: 3) {
                        FitBox(aspect: ImageAspect.of(frame, revision: model.annotationRevision), maxHeight: 120) {
                            MarkImage(url: frame, label: "Full screen frame for mark \(mark.index)", compact: true, annotated: mark.frameAnnotated, revision: model.annotationRevision) { model.view(mark.originalFrame) }
                        }
                        Text("Full screen").font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                    .frame(width: 92, alignment: .leading)
                    .help("What else was on screen at this moment")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    Image(nsImage: image).resizable()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .clipShape(.rect(cornerRadius: compact ? 4 : 6))
            .overlay(RoundedRectangle(cornerRadius: compact ? 4 : 6).strokeBorder(.separator.opacity(0.7), lineWidth: 0.5))
            .overlay(alignment: .topTrailing) {
                if annotated {
                    Image(systemName: "pencil.tip.crop.circle.fill")
                        .font(.system(size: compact ? 11 : 14, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(compact ? 3 : 5)
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
                        .padding(6)
                        .opacity(hovering ? 1 : 0)
                }
            }
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
            .font(.system(size: 12.5))
            .lineSpacing(2)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Narration: \(narration.focus)")
    }
}

/// The app, window, page title and URL at the mark. Folded by default: the meta line already says where.
struct ContextBlock: View {
    var context: MarkContext?

    var body: some View {
        if let c = context {
            InspectorSection("window", title: "Window", open: false) {
                VStack(alignment: .leading, spacing: 5) {
                    KeyValue(key: "App") {
                        HStack(spacing: 5) {
                            AppIcon(bundleID: c.bundleID, size: 14)
                            Text(c.appName ?? "Unknown app")
                            if let id = c.bundleID { Text(id).font(.system(size: 11).monospaced()).foregroundStyle(.tertiary).lineLimit(1) }
                        }
                    }
                    if let w = c.windowTitle.nonEmpty { KeyValue(key: "Window") { Text(w).textSelection(.enabled) } }
                    if c.browserTitle != c.windowTitle, let t = c.browserTitle.nonEmpty { KeyValue(key: "Page") { Text(t).textSelection(.enabled) } }
                    if let u = c.browserURL.nonEmpty {
                        KeyValue(key: "URL") {
                            if let url = URL(string: u) { Link(u, destination: url) } else { Text(u) }
                        }
                    }
                }
            }
        }
    }
}

struct KeyValue<Value: View>: View {
    var key: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
            value.font(.system(size: 12)).lineLimit(3)
        }
    }
}

// MARK: Page context

/// Problems first (they're usually why you marked), then the element under the pointer, the region's
/// elements, focus, and a link to the saved page. Flat: section headers and rows, no boxes.
struct PageContext: View {
    var model: SessionModel
    var snapshot: PageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = snapshot.error {
                Label("Page snapshot unavailable: \(error)", systemImage: "exclamationmark.circle")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            let problems = Array((snapshot.recent ?? []).filter(\.isProblem).suffix(8))
            if !problems.isEmpty {
                InspectorSection("problems", title: "Problems", tint: .red, trailing: "\(problems.count)") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(PageEvent.folded(problems).enumerated()), id: \.offset) { _, p in
                            PageEventRow(event: p.event, repeats: p.repeats)
                        }
                    }
                }
            }
            if let h = snapshot.hovered {
                InspectorSection("pointer", title: "Under pointer") { ElementView(element: h, full: true) }
            }
            if let region = snapshot.region {
                if let els = region.elements, !els.isEmpty {
                    let shown = Array(els.prefix(15))
                    InspectorSection("region", title: "In region", trailing: "\(els.count)", open: false) {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(shown.enumerated()), id: \.offset) { _, el in ElementView(element: el, full: false, compact: true) }
                        }
                    }
                } else if let note = region.note {
                    Label("Region: \(note)", systemImage: "rectangle.dashed").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if snapshot.focused != nil || snapshot.selection.nonEmpty != nil {
                InspectorSection("focus", title: "Focus and selection", open: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let f = snapshot.focused { ElementView(element: f, full: false) }
                        if let s = snapshot.selection.nonEmpty {
                            KeyValue(key: "Selected") { Text("“\(s)”").textSelection(.enabled) }
                        }
                    }
                }
            }
            if let page = model.url(snapshot.pageFile) {
                Button { Self.openInChrome(page) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.richtext")
                        Text("Open saved page in Chrome")
                        Image(systemName: "arrow.up.forward").font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.tint)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("The DOM, styles and images as they were at the mark\n\(page.path)")
            } else if let err = snapshot.pageError {
                Label("Saved page missing: \(err)", systemImage: "doc.badge.ellipsis")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    /// Safari can't render MHTML; Chrome can.
    static func openInChrome(_ url: URL) {
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
        VStack(alignment: .leading, spacing: compact ? 1 : 4) {
            if let t = element.text.nonEmpty {
                Text("“\(compact ? String(t.prefix(80)) : t)”")
                    .font(.system(size: compact ? 12 : 12.5, weight: compact ? .regular : .medium))
                    .lineLimit(compact ? 1 : 3)
                    .textSelection(.enabled)
            }
            Text(element.selector ?? element.tag ?? "element")
                .font(.system(size: 11).monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
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
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .help("React 19 stacks point at the transformed module, so the line can be off.")
            }
        }
    }
}

/// A typed note for the mark; its first line becomes the title. Saved on Return or when focus leaves.
/// No box: a light fill shows on hover and while typing.
struct NoteEditor: View {
    var model: SessionModel
    var mark: SessionMark
    @State private var text = ""
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(focused ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .frame(width: 20)
            TextField("Add a note (its first line becomes the title)", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...8)
                .focused($focused)
                .onSubmit { save() }
        }
        .padding(.vertical, 5)
        .padding(.trailing, 6)
        .background(focused ? AnyShapeStyle(.quaternary.opacity(0.7)) : hovering ? AnyShapeStyle(.quaternary.opacity(0.4)) : AnyShapeStyle(.clear),
                    in: .rect(cornerRadius: 5))
        .onHover { hovering = $0 }
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
