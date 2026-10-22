import SwiftUI

/// Inspector column. Three tabs, one job each: Marks (what you flagged, with everything known at that
/// moment), Transcript (what was said) and Events (what happened: app switches and page events in one
/// log). One find field filters all three; each tab's count shows its matches.
struct SidePanel: View {
    @Bindable var model: SessionModel

    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(model: model)
            Divider()
            Group {
                switch model.tab {
                case .marks: MarksList(model: model)
                case .transcript: TranscriptList(model: model)
                case .events: EventsList(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: Header

/// Text tabs with counts, then one find row whose trailing menu filters the current tab.
struct InspectorHeader: View {
    @Bindable var model: SessionModel
    @Namespace private var underline
    @FocusState private var findFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                ForEach(SessionModel.Tab.allCases) { tab in
                    TabButton(title: tab.rawValue, count: model.count(tab), finding: !model.query.isEmpty,
                              selected: model.tab == tab, underline: underline) {
                        withAnimation(.snappy(duration: 0.2)) { model.tab = tab }
                    }
                }
                Spacer(minLength: 0)
            }
            findRow
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .onChange(of: model.focusFind) { _, ask in
            guard ask else { return }
            findFocused = true
            model.focusFind = false
        }
    }

    private var findRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(findFocused ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            TextField("Find in session", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($findFocused)
                .onExitCommand { model.query = ""; findFocused = false }
                .accessibilityLabel("Find in marks, transcript and events")
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Clear (Esc)")
                .accessibilityLabel("Clear find")
            } else if !findFocused {
                Text("⌘F").font(.system(size: 11)).foregroundStyle(.quaternary)
            }
            filterMenu
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(height: 26)
        .background(.quaternary.opacity(findFocused ? 0.8 : 0.5), in: .rect(cornerRadius: 6))
    }

    @ViewBuilder private var filterMenu: some View {
        switch model.tab {
        case .marks where hasBothKinds:
            FilterMenu(active: model.markFilter != .all, label: model.markFilter.rawValue, help: "Show only marks or only shots") {
                Picker("Show", selection: $model.markFilter) {
                    ForEach(SessionModel.MarkFilter.allCases) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.inline)
            }
        case .events:
            FilterMenu(active: model.eventFilter != .all, label: model.eventFilter.rawValue, help: "Show one kind of event") {
                Picker("Show", selection: $model.eventFilter) {
                    ForEach(EventFilter.allCases) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.inline)
            }
        default:
            EmptyView()
        }
    }

    private var hasBothKinds: Bool { model.marks.contains(where: \.isShot) && model.marks.contains { !$0.isShot } }
}

/// A filter icon that names the filter while one is on, so the list's scope is never hidden.
private struct FilterMenu<Items: View>: View {
    var active: Bool
    var label: String
    var help: String
    @ViewBuilder var items: Items

    var body: some View {
        Menu { items } label: {
            HStack(spacing: 4) {
                if active { Text(label).font(.system(size: 11, weight: .semibold)) }
                Image(systemName: active ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(active ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 4)
            .frame(height: 22)
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(active ? "Showing \(label.lowercased()) only" : help)
    }
}

private struct TabButton: View {
    var title: String
    var count: Int
    var finding: Bool
    var selected: Bool
    var underline: Namespace.ID
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    Text(title).font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                    Text("\(count)")
                        .font(.system(size: 11, weight: finding ? .semibold : .medium).monospacedDigit())
                        .foregroundStyle(finding && count > 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .contentTransition(.numericText())
                }
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(count == 0 ? .tertiary : .secondary))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(hovering && !selected ? AnyShapeStyle(.quaternary.opacity(0.6)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 5))
                ZStack {
                    if selected {
                        Capsule().fill(Color.accentColor).frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: underline)
                    } else {
                        Color.clear.frame(height: 2)
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(title), \(count)")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Shown when find or a filter hides everything in a tab.
private struct NoMatches: View {
    var model: SessionModel

    var body: some View {
        ContentUnavailableView {
            Label("Nothing Matches", systemImage: "magnifyingglass")
        } description: {
            Text(model.query.isEmpty ? "Nothing of this kind in this session." : "Nothing here matches “\(model.query)”.")
        } actions: {
            Button(model.query.isEmpty ? "Show Everything" : "Clear Find") {
                if model.query.isEmpty { model.markFilter = .all; model.eventFilter = .all } else { model.query = "" }
            }
        }
    }
}

// MARK: Marks

struct MarksList: View {
    var model: SessionModel

    var body: some View {
        if model.marks.isEmpty {
            ContentUnavailableView {
                Label("No Marks", systemImage: "flag")
            } description: {
                Text("Press M (or ⌃⌥M while recording) to mark a moment, S for a region.")
            }
        } else if model.filteredMarks.isEmpty {
            NoMatches(model: model)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    // Not lazy: marks are few, and a lazy stack scrolls to the wrong spot when a row expands.
                    VStack(spacing: 0) {
                        ForEach(model.filteredMarks) { m in
                            MarkCard(model: model, mark: m, expanded: model.selectedMark == m.index)
                                .id(m.index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: model.selectedMark) { _, index in
                    guard let index else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(60))   // after the row has expanded
                        withAnimation(.snappy) { proxy.scrollTo(index, anchor: .top) }
                    }
                }
            }
        }
    }
}

/// A mark in the list: one compact row, or the whole mark inline when it's selected. Flat either way:
/// the open mark is a light tint across the column, not a card.
struct MarkCard: View {
    var model: SessionModel
    var mark: SessionMark
    var expanded: Bool
    @State private var hovering = false

    var body: some View {
        Group {
            if expanded {
                MarkDetail(model: model, mark: mark) {
                    withAnimation(.snappy) { model.select(nil, seek: false) }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .transition(.opacity)
            } else {
                Button {
                    withAnimation(.snappy) { model.select(mark.index) }
                } label: {
                    row.contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .accessibilityLabel("\(mark.isShot ? "Shot" : "Mark") \(mark.index) at \(Format.time(mark.offsetSeconds)): \(MarkText.title(mark))")
                .accessibilityHint("Seeks the video and shows details")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if expanded { Color.accentColor.opacity(0.06) } else if hovering { Rectangle().fill(.quaternary.opacity(0.5)) }
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy Markdown", systemImage: "doc.on.doc") { copy(model.markdown(for: mark)) }
            Button("Play from 5 s Before", systemImage: "play") { model.playFromBefore(mark) }
            if let url = model.url(mark.image) {
                Button("View Image", systemImage: "eye") { model.view(mark.originalImage) }
                Button("Reveal Image in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 10) {
            Thumbnail(url: model.url(mark.image), maxPixel: 240, revision: model.annotationRevision)
                .frame(width: 76, height: 48)
                .clipShape(.rect(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.separator.opacity(0.7), lineWidth: 0.5))
                .overlay(alignment: .topLeading) { MarkGlyph(mark: mark, size: 17).offset(x: -5, y: -5) }
            VStack(alignment: .leading, spacing: 3) {
                Text(Highlight.text(MarkText.title(mark), model.query))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                MarkMeta(model: model, mark: mark)
                if let hit = matchOutsideTitle {
                    Text(Highlight.text(hit, model.query))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// While finding: where a mark matched when it isn't in the title (narration, note, URL, window).
    private var matchOutsideTitle: String? {
        guard !model.query.isEmpty, !Highlight.matches(MarkText.title(mark), model.query) else { return nil }
        let c = mark.context
        return [mark.note, mark.narration.map(MarkText.withoutFlag), c?.browserURL, c?.windowTitle, c?.appName]
            .lazy.compactMap { $0.flatMap { Highlight.snippet($0, model.query) } }.first
    }
}

/// Where it happened, a problem count and the timecode. `showKind` adds "Shot" or "Mark" in front.
struct MarkMeta: View {
    var model: SessionModel
    var mark: SessionMark
    var showKind = false

    var body: some View {
        let c = mark.context
        let problems = (mark.browser?.recent ?? []).filter(\.isProblem).count
        HStack(spacing: 5) {
            if showKind {
                Text(mark.isShot ? "Shot" : "Mark")
                    .fontWeight(.semibold)
                    .foregroundStyle(mark.isShot ? Color.shot : Color.mark)
                if mark.isReview {
                    Text("added in review").foregroundStyle(.tertiary)
                        .help("Taken from the video afterwards: no live page snapshot")
                }
            }
            AppIcon(bundleID: c?.bundleID, size: 13)
            Text(where_(c))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if problems > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("\(problems)")
                }
                .foregroundStyle(.red)
                .help(problems == 1 ? "1 recent problem on the page" : "\(problems) recent problems on the page")
            }
            Text(Format.time(mark.offsetSeconds)).monospacedDigit().foregroundStyle(.tertiary)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    /// "localhost:5173/settings", or the window title for non-browser apps.
    private func where_(_ c: MarkContext?) -> String {
        if let u = c?.browserURL, let url = URL(string: u), let host = url.host() {
            return host + (url.port.map { ":\($0)" } ?? "") + (url.path() == "/" ? "" : url.path())
        }
        return c?.windowTitle.nonEmpty ?? c?.appName ?? ""
    }
}

// MARK: Transcript

struct TranscriptList: View {
    var model: SessionModel

    var body: some View {
        if model.transcript.isEmpty {
            ContentUnavailableView("Silent Recording", systemImage: "mic.slash", description: Text("There's no narration for this session."))
        } else {
            let rows = model.transcriptMatches
            if rows.isEmpty {
                NoMatches(model: model)
            } else {
                let current = model.sentenceAt(model.focusTime)
                let marksAt = model.marksBySentence
                ScrollViewReader { proxy in
                    List(rows, id: \.self) { i in
                        let s = model.transcript[i]
                        TimedRow(time: s.start, highlighted: s == current) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(Highlight.text(s.text, model.query))
                                    .font(.system(size: 13))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                // The marks made during this sentence; click one to open it.
                                ForEach(marksAt[i] ?? []) { m in
                                    Button {
                                        withAnimation(.snappy) { model.tab = .marks; model.select(m.index) }
                                    } label: { MarkGlyph(mark: m, size: 16) }
                                    .buttonStyle(.plain)
                                    .help("\(m.isShot ? "Shot" : "Mark") \(m.index): \(MarkText.title(m))")
                                    .accessibilityLabel("Open \(m.isShot ? "shot" : "mark") \(m.index)")
                                }
                            }
                        } action: { model.seek(s.start) }
                        .id(i)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 10))
                        .listRowBackground(s == current ? Color.accentColor.opacity(0.1) : nil)
                    }
                    .listStyle(.plain)
                    .onChange(of: current) { _, s in
                        guard model.isPlaying || model.previewTime != nil, let s, let i = model.transcript.firstIndex(of: s) else { return }
                        withAnimation { proxy.scrollTo(i, anchor: .center) }
                    }
                }
            }
        }
    }
}

// MARK: Events

/// App switches and page events in one time-ordered log. Problems are red; identical events in a
/// quick run share a row with a ×N count. The row at the playhead is lit and followed while playing.
struct EventsList: View {
    var model: SessionModel

    var body: some View {
        if model.events.isEmpty {
            ContentUnavailableView("No Events", systemImage: "list.bullet.rectangle",
                                   description: Text("App switches and page events appear here. Set up the Chrome extension (Help menu) to capture clicks, navigation, console errors and failed requests."))
        } else {
            let events = model.filteredEvents
            if events.isEmpty {
                NoMatches(model: model)
            } else {
                let current = events.last { $0.time <= model.focusTime + 0.05 }?.id
                ScrollViewReader { proxy in
                    List(events) { e in
                        TimedRow(time: e.time, highlighted: e.id == current) {
                            EventRow(event: e, query: model.query)
                        } action: { model.seek(e.time) }
                        .id(e.id)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 10))
                        .listRowBackground(e.id == current ? Color.accentColor.opacity(0.1) : nil)
                    }
                    .listStyle(.plain)
                    .onChange(of: current) { _, id in
                        guard model.isPlaying || model.previewTime != nil, let id else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
    }
}

struct EventRow: View {
    var event: SessionEvent
    var query: String

    var body: some View {
        switch event.source {
        case .app(let c): AppEventRow(context: c, query: query)
        case .page(let e): PageEventRow(event: e, repeats: event.repeats, query: query)
        }
    }
}

/// The front app or window changed.
private struct AppEventRow: View {
    var context: MarkContext?
    var query: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            AppIcon(bundleID: context?.bundleID, size: 14)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                .frame(width: 15)
            VStack(alignment: .leading, spacing: 1) {
                Text(Highlight.text(context?.appName ?? "Unknown app", query)).font(.system(size: 12.5, weight: .medium))
                if let sub = (context?.browserURL.nonEmpty.map(Format.shortURL)) ?? context?.windowTitle.nonEmpty {
                    Text(Highlight.text(sub, query))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .help([context?.appName, context?.windowTitle, context?.browserURL].compactMap { $0.nonEmpty }.joined(separator: "\n"))
    }
}

/// One page event in at most two lines: the thing itself, then a quieter detail line. Used in the
/// Events log and in a mark's problems.
struct PageEventRow: View {
    var event: PageEvent
    var repeats = 1
    var query = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: PageEventStyle.symbol(event))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PageEventStyle.color(event))
                .frame(width: 15)
                .accessibilityLabel(PageEventStyle.name(event))
            VStack(alignment: .leading, spacing: 1) { lines }
                .frame(maxWidth: .infinity, alignment: .leading)
            if repeats > 1 {
                Text("×\(repeats)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .help("\(repeats) in a row")
            }
        }
        .help(event.summary)
    }

    @ViewBuilder private var lines: some View {
        switch event.kind {
        case "request":
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(event.method ?? "?").font(.system(size: 11, weight: .semibold).monospaced()).foregroundStyle(.secondary)
                if let status = event.status {
                    Text(status == 0 ? "failed" : "\(status)")
                        .font(.system(size: 11, weight: .semibold).monospaced())
                        .foregroundStyle(event.isProblem ? .red : .green)
                }
                primary(Format.shortURL(event.requestUrl ?? ""), lines: 1)
            }
            detail([event.error ?? event.body, event.ms.map { "\(Format.number($0.rounded())) ms" }, event.slow == true ? "slow" : nil])
        case "click":
            primary(event.element?.text.nonEmpty.map { "Click “\($0)”" } ?? "Click", lines: 1)
            detail([event.element?.selector], mono: true)
        case "nav":
            primary(Format.shortURL(event.url ?? ""), lines: 1)
            detail([event.how])
        case "console":
            primary(trimmed(event.message), lines: 2)
        case "error":
            primary(trimmed(event.message ?? event.source), lines: 2)
            detail([event.type], mono: true)
        default:
            primary(event.summary, lines: 2)
        }
    }

    private func trimmed(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    private func primary(_ s: String, lines: Int) -> some View {
        Text(Highlight.text(s, query))
            .font(.system(size: 12.5))
            .lineLimit(lines)
            .truncationMode(lines == 1 ? .middle : .tail)
    }

    @ViewBuilder private func detail(_ parts: [String?], mono: Bool = false) -> some View {
        let text = parts.compactMap { $0?.split(whereSeparator: \.isNewline).first.map(String.init) }.filter { !$0.isEmpty }.joined(separator: " · ")
        if !text.isEmpty {
            Text(text)
                .font(mono ? .system(size: 11).monospaced() : .system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// A row with a timecode that seeks when clicked.
struct TimedRow<Content: View>: View {
    var time: Double
    var highlighted: Bool
    @ViewBuilder var content: Content
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Format.time(time))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .frame(width: 32, alignment: .trailing)
                content
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Seeks to \(Format.time(time))")
    }
}
