import SwiftUI

/// Inspector column: marks (default), transcript, page events and activity.
struct SidePanel: View {
    @Bindable var model: SessionModel

    var body: some View {
        VStack(spacing: 0) {
            InspectorTabs(model: model)
            Divider()
            switch model.tab {
            case .marks: MarksList(model: model)
            case .transcript: TranscriptList(model: model)
            case .page: PageEventsList(model: model)
            case .activity: ActivityList(model: model)
            }
        }
    }
}

/// One row of text tabs with counts, instead of stacked segmented controls. The marks filter is a small
/// menu at the end, shown only when a session has both marks and shots.
struct InspectorTabs: View {
    @Bindable var model: SessionModel
    @Namespace private var underline

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SessionModel.Tab.allCases) { tab in
                TabButton(title: tab == .page ? "Page" : tab.rawValue, count: count(tab),
                          selected: model.tab == tab, underline: underline) {
                    withAnimation(.snappy(duration: 0.2)) { model.tab = tab }
                }
            }
            Spacer(minLength: 0)
            if model.tab == .marks, hasBothKinds { filterMenu }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private var hasBothKinds: Bool { model.marks.contains(where: \.isShot) && model.marks.contains { !$0.isShot } }

    private var filterMenu: some View {
        Menu {
            Picker("Show", selection: $model.markFilter) {
                ForEach(SessionModel.MarkFilter.allCases) { f in Text("\(f.rawValue)  \(filterCount(f))").tag(f) }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: model.markFilter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(model.markFilter == .all ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(.bottom, 6)
        .help(model.markFilter == .all ? "Show only marks or only shots" : "Showing \(model.markFilter.rawValue.lowercased()) only")
    }

    private func count(_ tab: SessionModel.Tab) -> Int {
        switch tab {
        case .marks: model.marks.count
        case .transcript: model.transcript.count
        case .page: model.pageEvents.count
        case .activity: model.activity.count
        }
    }

    private func filterCount(_ f: SessionModel.MarkFilter) -> Int {
        switch f {
        case .all: model.marks.count
        case .mark: model.marks.filter { !$0.isShot }.count
        case .screenshot: model.marks.filter(\.isShot).count
        }
    }
}

private struct TabButton: View {
    var title: String
    var count: Int
    var selected: Bool
    var underline: Namespace.ID
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(title).font(.system(size: 12, weight: selected ? .semibold : .medium))
                    if count > 0 {
                        Text("\(count)").font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(count == 0 ? .tertiary : .secondary))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
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

// MARK: Marks

struct MarksList: View {
    var model: SessionModel

    var body: some View {
        if model.filteredMarks.isEmpty {
            ContentUnavailableView {
                Label(model.marks.isEmpty ? "No Marks" : "Nothing Matches", systemImage: "flag")
            } description: {
                Text(model.marks.isEmpty ? "Press ⌃⌥M or ⌃⌥S while recording to mark a moment." : "No marks of this kind.")
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    // Not lazy: marks are few, and a lazy stack scrolls to the wrong spot when a card expands.
                    VStack(spacing: 4) {
                        ForEach(model.filteredMarks) { m in
                            MarkCard(model: model, mark: m, expanded: model.selectedMark == m.index)
                                .id(m.index)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: model.selectedMark) { _, index in
                    guard let index else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(60))   // after the card has expanded
                        withAnimation(.snappy) { proxy.scrollTo(index, anchor: .top) }
                    }
                }
            }
        }
    }
}

struct MarkCard: View {
    var model: SessionModel
    var mark: SessionMark
    var expanded: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if expanded {
                MarkDetail(model: model, mark: mark) {
                    withAnimation(.snappy) { model.select(nil, seek: false) }
                }
                .padding(12)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            } else {
                Button {
                    withAnimation(.snappy) { model.select(mark.index) }
                } label: {
                    row.contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("\(mark.isShot ? "Shot" : "Mark") \(mark.index), \(Format.time(mark.offsetSeconds)): \(MarkText.title(mark))")
                .accessibilityHint("Seeks the video and shows details")
            }
        }
        .background {
            if expanded {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
            } else if hovering {
                RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.6))
            }
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
        HStack(alignment: .top, spacing: 12) {
            Thumbnail(url: model.url(mark.image), maxPixel: 280, revision: model.annotationRevision)
                .frame(width: 92, height: 58)
                .clipShape(.rect(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.separator.opacity(0.7), lineWidth: 0.5))
                .overlay(alignment: .topLeading) { MarkGlyph(mark: mark, size: 18).offset(x: -5, y: -5) }
            VStack(alignment: .leading, spacing: 4) {
                Text(MarkText.title(mark))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                MarkMeta(model: model, mark: mark)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// App icon, where it happened, timecode and a problem count.
struct MarkMeta: View {
    var model: SessionModel
    var mark: SessionMark

    var body: some View {
        let c = mark.context
        let problems = (mark.browser?.recent ?? []).filter(\.isProblem).count
        HStack(spacing: 5) {
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
                .help(problems == 1 ? "1 recent error on the page" : "\(problems) recent errors on the page")
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
            let current = model.sentenceAt(model.focusTime)
            ScrollViewReader { proxy in
                List(Array(model.transcript.enumerated()), id: \.offset) { i, s in
                    TimedRow(time: s.start, highlighted: s == current) {
                        Text(s.text).foregroundStyle(s == current ? .primary : .secondary)
                    } action: { model.seek(s.start) }
                    .id(i)
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

// MARK: Page events

struct PageEventsList: View {
    var model: SessionModel

    var body: some View {
        if model.pageEvents.isEmpty {
            ContentUnavailableView("No Page Events", systemImage: "puzzlepiece.extension",
                                   description: Text("Install the Chrome extension (see README) to capture clicks, navigation, console errors and failed requests."))
        } else {
            List(Array(model.pageEvents.enumerated()), id: \.offset) { _, entry in
                TimedRow(time: entry.offsetSeconds, highlighted: false) {
                    PageEventRow(event: entry.event)
                } action: { model.seek(entry.offsetSeconds) }
                .listRowBackground(entry.event.isProblem ? Color.red.opacity(0.07) : nil)
            }
            .listStyle(.plain)
        }
    }
}

struct PageEventRow: View {
    var event: PageEvent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: PageEventStyle.symbol(event))
                .foregroundStyle(PageEventStyle.color(event))
                .frame(width: 16)
                .accessibilityLabel(PageEventStyle.name(event))
            VStack(alignment: .leading, spacing: 3) {
                switch event.kind {
                case "request":
                    HStack(spacing: 5) {
                        Tag(text: event.method ?? "?", tint: .secondary)
                        if let status = event.status { Tag(text: "\(status)", tint: event.isProblem ? .red : .green) }
                        if let ms = event.ms { Text("\(Format.number(ms.rounded())) ms").font(.caption).foregroundStyle(.secondary) }
                        if event.slow == true { Tag(text: "slow", tint: .orange) }
                    }
                    Text(event.requestUrl ?? "").font(.callout).lineLimit(1).truncationMode(.middle)
                    if let detail = event.error ?? event.body {
                        Text(detail).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(3)
                    }
                case "click":
                    Text(event.element?.text.nonEmpty.map { "“\($0)”" } ?? "Click").font(.callout)
                    Text(event.element?.selector ?? "").font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                case "nav":
                    Text(event.url ?? "").font(.callout).lineLimit(1).truncationMode(.middle)
                    Text(event.how ?? "").font(.caption).foregroundStyle(.secondary)
                case "console":
                    Text(event.message ?? "").font(.callout).lineLimit(3)
                    Text("console.\(event.level ?? "log")").font(.caption.monospaced()).foregroundStyle(.secondary)
                case "error":
                    Text(event.message ?? event.source ?? "").font(.callout).lineLimit(3)
                    Text(event.type ?? "Error").font(.caption.monospaced()).foregroundStyle(.secondary)
                default:
                    Text(event.summary).font(.callout)
                }
            }
        }
    }
}

struct Tag: View {
    var text: String
    var tint: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold).monospaced())
            .foregroundStyle(tint)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(tint.opacity(0.13), in: .rect(cornerRadius: 4))
    }
}

// MARK: Activity

struct ActivityList: View {
    var model: SessionModel

    var body: some View {
        if model.activity.isEmpty {
            ContentUnavailableView("No Activity", systemImage: "macwindow", description: Text("No app or window changes were recorded."))
        } else {
            List(Array(model.activity.enumerated()), id: \.offset) { _, a in
                TimedRow(time: a.offsetSeconds, highlighted: false) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(model.color(forApp: a.context?.appName)).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.context?.appName ?? "Unknown app").font(.callout.weight(.medium))
                            if let sub = a.context?.browserURL ?? a.context?.windowTitle, !sub.isEmpty {
                                Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                        }
                    }
                } action: { model.seek(a.offsetSeconds) }
            }
            .listStyle(.plain)
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
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Format.time(time))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .frame(width: 34, alignment: .trailing)
                content
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Seeks to \(Format.time(time))")
    }
}
