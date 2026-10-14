import AVFoundation
import SwiftUI

/// Every lane on one time axis: the ruler (with the mark pins on it), active app, page events, narration.
/// One playhead spans all of them; click or drag anywhere to seek; hover shows the frame at that moment
/// and what was going on.
struct SessionTimeline: View {
    var model: SessionModel
    @State private var hover: CGPoint?
    @State private var hoveredPin: Int?
    @State private var cardSize: CGSize = .zero
    @State private var previews: FramePreviews?
    /// Decided when a drag starts: Shift selects a range, otherwise the drag seeks.
    @State private var selectAnchor: Double?
    @State private var dragging = false

    private static let labelWidth: CGFloat = 72
    private static let laneGap: CGFloat = 7
    private static let pinSize: CGFloat = 18
    /// Time labels get their own strip at the top of the ruler, so a pin never hides one.
    private static let labelStrip: CGFloat = 13

    enum Lane: CaseIterable {
        case ruler, apps, page, speech
        var height: CGFloat {
            switch self { case .ruler: 32; case .apps: 26; case .page: 16; case .speech: 16 }
        }
        var title: String {
            switch self { case .ruler: ""; case .apps: "Apps"; case .page: "Page"; case .speech: "Voice" }
        }
        var symbol: String {
            switch self { case .ruler: ""; case .apps: "macwindow"; case .page: "globe"; case .speech: "waveform" }
        }
    }

    private var lanes: [Lane] {
        Lane.allCases.filter {
            switch $0 {
            case .page: !model.pageEvents.isEmpty
            case .speech: !model.transcript.isEmpty
            case .apps: !model.activity.isEmpty
            default: true
            }
        }
    }

    private func top(of lane: Lane) -> CGFloat {
        var y: CGFloat = 0
        for l in lanes { if l == lane { return y }; y += l.height + Self.laneGap }
        return y
    }

    private var totalHeight: CGFloat { lanes.reduce(0) { $0 + $1.height } + Self.laneGap * CGFloat(lanes.count - 1) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack(alignment: .topLeading) {
                ForEach(lanes.filter { $0 != .ruler }, id: \.self) { lane in
                    Label(lane.title, systemImage: lane.symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .labelStyle(LaneLabelStyle())
                        .frame(width: Self.labelWidth, height: lane.height, alignment: .leading)
                        .offset(y: top(of: lane))
                }
            }
            .frame(width: Self.labelWidth, height: totalHeight, alignment: .topLeading)
            .accessibilityHidden(true)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    rails(width: w)
                    scrubSurface(width: w)
                    if let hover { hoverLine(at: hover) }
                    playheadLine(width: w)   // under the lanes, so pins stay readable
                    ForEach(lanes, id: \.self) { lane in
                        laneView(lane, width: w)
                            .frame(width: w, height: lane.height, alignment: .topLeading)
                            .offset(y: top(of: lane))
                    }
                    playheadHandle(width: w)
                    TimelineEditOverlay(model: model, width: w, height: totalHeight)
                }
                // An overlay, so the card never changes the lanes' layout.
                .overlay(alignment: .topLeading) {
                    if let hover { hoverCard(at: hover, width: w) }
                }
                .onContinuousHover(coordinateSpace: .local) { phase in
                    if case .active(let p) = phase {
                        hover = p
                        previews?.request(min(t(p.x, w), max(0, model.duration - 0.5)))
                    } else {
                        hover = nil
                    }
                }
                .task(id: PreviewKey(width: w, asset: ObjectIdentifier(model.playbackAsset))) {
                    previews = FramePreviews(asset: model.playbackAsset)
                    let args = CommandLine.arguments
                    if args.contains("--library"), let i = args.firstIndex(of: "--timeline-hover"),
                       i + 1 < args.count, let fraction = Double(args[i + 1]) {
                        let point = CGPoint(x: min(1, max(0, fraction)) * w, y: 0)
                        hover = point
                        previews?.request(min(t(point.x, w), max(0, model.duration - 0.5)))
                    }
                }
            }
            .frame(height: totalHeight)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline")
    }

    private func x(_ t: Double, _ w: CGFloat) -> CGFloat { CGFloat(t / model.duration) * w }
    private func t(_ x: CGFloat, _ w: CGFloat) -> Double { Double(max(0, min(w, x)) / max(w, 1)) * model.duration }

    // MARK: Lanes

    @ViewBuilder private func laneView(_ lane: Lane, width w: CGFloat) -> some View {
        switch lane {
        case .ruler: ZStack(alignment: .topLeading) { ruler(width: w); markPins(width: w) }
        case .apps: appSegments(width: w)
        case .page: pageDots(width: w)
        case .speech: speechSegments(width: w)
        }
    }

    /// Soft tracks behind the lanes, like an editor's timeline.
    private func rails(width w: CGFloat) -> some View {
        ForEach(lanes.filter { $0 != .ruler }, id: \.self) { lane in
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.55))
                .frame(width: w, height: lane.height)
                .offset(y: top(of: lane))
        }
        .allowsHitTesting(false)
    }

    private func scrubSurface(width w: CGFloat) -> some View {
        Rectangle()
            .fill(.clear)
            .contentShape(.rect)
            .frame(width: w, height: totalHeight)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if !dragging {
                        dragging = true
                        selectAnchor = NSEvent.modifierFlags.contains(.shift) ? t(g.startLocation.x, w) : nil
                    }
                    let time = t(g.location.x, w)
                    if let anchor = selectAnchor {
                        model.selection = min(anchor, time)...max(anchor, time)
                    } else {
                        model.seek(time)
                    }
                }
                .onEnded { _ in
                    dragging = false
                    if let s = model.selection, s.upperBound - s.lowerBound < 0.1, selectAnchor != nil { model.selection = nil }
                    selectAnchor = nil
                })
            .accessibilityElement()
            .accessibilityLabel("Playhead")
            .accessibilityValue(Format.time(model.currentTime))
            .accessibilityAdjustableAction { dir in model.skip(dir == .increment ? 5 : -5) }
    }

    /// Ticks at round steps (0:00, 0:05, 0:10…) with unlabeled minor ticks between.
    private func ruler(width w: CGFloat) -> some View {
        let steps: [Double] = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600]
        let fit = max(1, Double(w / 70))
        let step = steps.first { model.duration / $0 <= fit } ?? 3600
        let minor = step / (step >= 10 && Int(step) % 5 == 0 ? 5 : 2)
        let duration = model.duration
        return Canvas { ctx, size in
            for tick in stride(from: 0, through: duration, by: minor) {
                let px = x(tick, w)
                let major = abs(tick / step - (tick / step).rounded()) < 0.001
                let h: CGFloat = major ? 6 : 3
                ctx.fill(Path(CGRect(x: px - 0.5, y: size.height - h, width: 1, height: h)),
                         with: .style(major ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary)))
                guard major else { continue }
                let label = ctx.resolve(Text(Format.time(tick)).font(.system(size: 10, weight: .medium).monospacedDigit()).foregroundStyle(.tertiary))
                let s = label.measure(in: size)
                let lx = min(max(0, px - s.width / 2), size.width - s.width)
                ctx.draw(label, in: CGRect(x: lx, y: 0, width: s.width, height: s.height))
            }
        }
        .allowsHitTesting(false)
    }

    private func markPins(width w: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(model.marks) { m in
                let selected = model.selectedMark == m.index
                Button {
                    withAnimation(.snappy) { model.select(m.index); model.tab = .marks }
                } label: {
                    MarkGlyph(mark: m, size: Self.pinSize, selected: selected)
                        .scaleEffect(selected || hoveredPin == m.index ? 1.15 : 1)
                        .animation(.snappy(duration: 0.18), value: hoveredPin)
                }
                .buttonStyle(.plain)
                .focusable()
                .onHover { hoveredPin = $0 ? m.index : (hoveredPin == m.index ? nil : hoveredPin) }
                .offset(x: x(m.offsetSeconds, w) - Self.pinSize / 2, y: Self.labelStrip + (Lane.ruler.height - Self.labelStrip - Self.pinSize) / 2)
                .zIndex(selected ? 1 : 0)
                .accessibilityLabel("\(m.isShot ? "Shot" : "Mark") \(m.index) at \(Format.time(m.offsetSeconds)): \(MarkText.title(m))")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    /// Same-app runs merge into one band; a thin divider marks each window or tab change inside it.
    struct AppRun { var start: Double; var end: Double; var app: String?; var bundleID: String?; var changes: [Double] }

    private var appRuns: [AppRun] {
        var runs: [AppRun] = []
        let acts = model.activity
        for (i, a) in acts.enumerated() {
            let end = i + 1 < acts.count ? acts[i + 1].offsetSeconds : model.duration
            let app = a.context?.appName
            if var last = runs.last, last.app == app {
                last.changes.append(a.offsetSeconds)
                last.end = end
                runs[runs.count - 1] = last
            } else {
                runs.append(AppRun(start: a.offsetSeconds, end: end, app: app, bundleID: a.context?.bundleID, changes: []))
            }
        }
        return runs
    }

    private func appSegments(width w: CGFloat) -> some View {
        let runs = appRuns
        let icons = Dictionary(runs.map { ($0.bundleID ?? "", AppIcons.icon($0.bundleID)) }, uniquingKeysWith: { a, _ in a })
        let colors = runs.map { model.color(forApp: $0.app) }
        return Canvas { ctx, size in
            for (i, run) in runs.enumerated() {
                let rect = CGRect(x: x(run.start, w), y: 0, width: max(2, x(run.end, w) - x(run.start, w)), height: size.height)
                    .insetBy(dx: 1, dy: 0)
                let shape = Path(roundedRect: rect, cornerRadius: 6)
                ctx.fill(shape, with: .linearGradient(Gradient(colors: [colors[i].opacity(0.95), colors[i]]),
                                                      startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
                ctx.stroke(shape, with: .color(.white.opacity(0.18)), lineWidth: 0.5)
                for c in run.changes {
                    ctx.fill(Path(roundedRect: CGRect(x: x(c, w) - 0.75, y: 6, width: 1.5, height: size.height - 12), cornerRadius: 0.75),
                             with: .color(.white.opacity(0.5)))
                }
                var textX = rect.minX + 7
                if rect.width > 28, let icon = icons[run.bundleID ?? ""] {
                    ctx.draw(ctx.resolve(Image(nsImage: icon)), in: CGRect(x: rect.minX + 5, y: (size.height - 16) / 2, width: 16, height: 16))
                    textX = rect.minX + 25
                }
                let label = ctx.resolve(Text(run.app ?? "").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white))
                let s = label.measure(in: size)
                if textX + s.width + 6 < rect.maxX {
                    ctx.draw(label, in: CGRect(x: textX, y: (size.height - s.height) / 2, width: s.width, height: s.height))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func pageDots(width w: CGFloat) -> some View {
        let events = model.pageEvents
        return Canvas { ctx, size in
            for e in events where !e.event.isProblem { dot(ctx, e, size, w, r: 3.5) }
            for e in events where e.event.isProblem { dot(ctx, e, size, w, r: 4.5) }
        }
        .allowsHitTesting(false)
    }

    private func dot(_ ctx: GraphicsContext, _ e: BrowserEntry, _ size: CGSize, _ w: CGFloat, r: CGFloat) {
        let rect = CGRect(x: x(e.offsetSeconds, w) - r, y: size.height / 2 - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(Color(nsColor: .textBackgroundColor)))
        ctx.fill(Path(ellipseIn: rect), with: .color(PageEventStyle.color(e.event)))
    }

    /// Narration as soft capsules; the sentence under the playhead lights up.
    private func speechSegments(width w: CGFloat) -> some View {
        let current = model.sentenceAt(model.currentTime)
        let sentences = model.transcript
        return Canvas { ctx, size in
            for s in sentences {
                let rect = CGRect(x: x(s.start, w) + 1, y: 4, width: max(3, x(s.end, w) - x(s.start, w) - 2), height: size.height - 8)
                ctx.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2),
                         with: .color(.accentColor.opacity(s == current ? 0.85 : 0.35)))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Playhead + hover

    private func playheadLine(width w: CGFloat) -> some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 1.5, height: totalHeight)
            .offset(x: x(model.currentTime, w) - 0.75, y: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// A small head on top of the line. The time itself is in the transport and the hover card; a pill
    /// here would cover the pin of the mark you just selected.
    private func playheadHandle(width w: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 10, y: 0)); p.addLine(to: CGPoint(x: 5, y: 6)); p.closeSubpath()
        }
        .fill(Color.accentColor)
        .frame(width: 10, height: 6)
        .offset(x: x(model.currentTime, w) - 5, y: -3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func hoverLine(at p: CGPoint) -> some View {
        Rectangle()
            .fill(.secondary.opacity(0.45))
            .frame(width: 1, height: totalHeight)
            .offset(x: p.x - 0.5, y: 0)
            .allowsHitTesting(false)
    }

    /// The frame at the pointer, its time, and everything going on then: app and window, what was being
    /// said, a mark or page event right under the pointer.
    private func hoverCard(at p: CGPoint, width w: CGFloat) -> some View {
        let time = t(p.x, w)
        let ctx = model.contextAt(time)
        let near = Double(8 / max(w, 1)) * model.duration
        let mark = model.marks.min { abs($0.offsetSeconds - time) < abs($1.offsetSeconds - time) }
            .flatMap { abs($0.offsetSeconds - time) <= near * 1.5 ? $0 : nil }
        let event = model.pageEvents.min { abs($0.offsetSeconds - time) < abs($1.offsetSeconds - time) }
            .flatMap { abs($0.offsetSeconds - time) <= near ? $0 : nil }
        let said = model.sentenceAt(time)
        let aspect = model.videoSize.map { $0.width / $0.height } ?? 16 / 10
        let previewWidth = max(1, min(240, w - 16))
        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(Color.stage)
                if let image = previews?.image {
                    Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                }
                Text(Format.time(time))
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.black.opacity(0.65), in: .rect(cornerRadius: 4))
                    .padding(6)
            }
            .frame(width: previewWidth, height: previewWidth / aspect)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 5) {
                if let mark {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        MarkGlyph(mark: mark, size: 16)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                        Text(MarkText.title(mark)).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                    }
                }
                if let ctx {
                    HStack(spacing: 6) {
                        AppIcon(bundleID: ctx.bundleID, size: 14)
                        Text(ctx.appName ?? "Unknown app").font(.system(size: 12, weight: .medium))
                    }
                    if let sub = (ctx.browserTitle ?? ctx.windowTitle).nonEmpty {
                        Text(sub).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
                if let said {
                    Text("“\(said.text)”").font(.system(size: 11.5)).foregroundStyle(.primary).lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let event {
                    HStack(spacing: 5) {
                        Image(systemName: PageEventStyle.symbol(event.event)).foregroundStyle(PageEventStyle.color(event.event))
                        Text(event.event.summary).lineLimit(2)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
            .frame(width: previewWidth, alignment: .leading)
        }
        .padding(8)
        .background(.background, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .fixedSize()
        .onGeometryChange(for: CGSize.self, of: \.size) { cardSize = $0 }
        // Centred over the pointer, kept inside the timeline, and always above it: it sits at the bottom
        // of the window, so a card below it would be cut off.
        .offset(x: min(max(0, p.x - cardSize.width / 2), max(0, w - cardSize.width)),
                y: -cardSize.height - 10)
        .allowsHitTesting(false)
    }
}

/// Small frames from the recording for the hover card. Only the latest request runs, and frames are
/// cached by half-second, so sweeping across the timeline stays smooth.
@MainActor @Observable
final class FramePreviews {
    private(set) var image: CGImage?
    @ObservationIgnored private let generator: AVAssetImageGenerator
    @ObservationIgnored private var cache: [Int: CGImage] = [:]
    @ObservationIgnored private var order: [Int] = []
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var requestedKey: Int?

    init(asset: AVAsset) {
        generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        // A nearby frame is fine for a preview and much faster than an exact one.
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.25, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)
    }

    func request(_ t: Double) {
        requestedKey = Int((t * 2).rounded())
        guard pending == nil else { return }
        pending = Task { [generator] in
            defer { pending = nil }
            // Finish one frame while movement continues, then render the latest requested position.
            while let key = requestedKey {
                requestedKey = nil
                if let hit = cache[key] { image = hit; continue }
                guard let (frame, _) = try? await generator.image(at: CMTime(seconds: Double(key) / 2, preferredTimescale: 600)) else { continue }
                store(frame, key)
                image = frame
            }
        }
    }

    private func store(_ frame: CGImage, _ key: Int) {
        guard cache[key] == nil else { return }
        cache[key] = frame
        order.append(key)
        if order.count > 150 { cache[order.removeFirst()] = nil }
    }
}

/// Rebuild the previews when the width changes or an edit swaps the video.
private struct PreviewKey: Hashable { var width: CGFloat; var asset: ObjectIdentifier }

struct LaneLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 10, weight: .semibold)).frame(width: 13).foregroundStyle(.tertiary)
            configuration.title
        }
    }
}

enum PageEventStyle {
    static func color(_ e: PageEvent) -> Color {
        if e.isProblem { return .red }
        switch e.kind {
        case "click": return .blue
        case "nav": return .purple
        case "request": return .teal
        default: return .gray
        }
    }

    static func symbol(_ e: PageEvent) -> String {
        switch e.kind {
        case "click": return "cursorarrow.click.2"
        case "nav": return "arrow.triangle.turn.up.right.circle"
        case "request": return "network"
        case "console": return "text.bubble"
        case "error": return "exclamationmark.octagon"
        default: return "circle"
        }
    }

    static func name(_ e: PageEvent) -> String {
        ["click": "Click", "nav": "Navigation", "console": "Console", "error": "Error", "request": "Request"][e.kind] ?? e.kind
    }
}
