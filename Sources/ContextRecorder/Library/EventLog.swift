import ImageIO
import SwiftUI

/// One row of the inspector's Events log: an app or window change from the activity log, or a page
/// event from the Chrome extension. Identical page events in a quick run are folded into one row.
struct SessionEvent: Identifiable {
    enum Source {
        case app(MarkContext?)
        case page(PageEvent)
    }

    let id: Int
    let time: Double
    let source: Source
    /// How many identical events this row stands for (consecutive, within a few seconds).
    var repeats = 1

    var isProblem: Bool {
        if case .page(let e) = source { return e.isProblem }
        return false
    }

    /// What find matches against.
    var searchText: String {
        switch source {
        case .app(let c): return [c?.appName, c?.windowTitle, c?.browserURL, c?.browserTitle].compactMap { $0 }.joined(separator: " ")
        case .page(let e): return e.summary
        }
    }

    func passes(_ filter: EventFilter) -> Bool {
        switch (filter, source) {
        case (.all, _): return true
        case (.problems, _): return isProblem
        case (.navigation, .app): return true
        case (.navigation, .page(let e)): return e.kind == "nav"
        case (.clicks, .page(let e)): return e.kind == "click"
        case (.network, .page(let e)): return e.kind == "request"
        case (.console, .page(let e)): return e.kind == "console" || e.kind == "error"
        default: return false
        }
    }
}

enum EventFilter: String, CaseIterable, Identifiable {
    case all = "All events", problems = "Problems", navigation = "Apps and pages", clicks = "Clicks",
         network = "Network", console = "Console"
    var id: String { rawValue }
}

enum EventLog {
    /// Seconds within which identical page events fold into one row.
    static let foldWindow = 5.0

    /// Activity and page events merged in time order (app changes first at equal times).
    static func build(activity: [ActivityEntry], page: [BrowserEntry]) -> [SessionEvent] {
        var merged: [(time: Double, order: Int, source: SessionEvent.Source)] = []
        for (i, a) in activity.enumerated() { merged.append((a.offsetSeconds, i, .app(a.context))) }
        for (i, p) in page.enumerated() { merged.append((p.offsetSeconds, activity.count + i, .page(p.event))) }
        merged.sort { $0.time != $1.time ? $0.time < $1.time : $0.order < $1.order }

        var out: [SessionEvent] = []
        for item in merged {
            if case .page(let e) = item.source, let last = out.last, case .page(let prev) = last.source,
               prev.summary == e.summary, item.time - last.time <= foldWindow {
                out[out.count - 1].repeats += 1
                continue
            }
            out.append(SessionEvent(id: out.count, time: item.time, source: item.source))
        }
        return out
    }
}

extension PageEvent {
    /// Consecutive identical events folded together, for short lists such as a mark's recent problems.
    static func folded(_ events: [PageEvent]) -> [(event: PageEvent, repeats: Int)] {
        var out: [(event: PageEvent, repeats: Int)] = []
        for e in events {
            if let last = out.last, last.event.summary == e.summary { out[out.count - 1].repeats += 1 } else { out.append((e, 1)) }
        }
        return out
    }
}

/// Find-match highlighting for list text.
enum Highlight {
    static func text(_ s: String, _ query: String) -> AttributedString {
        var a = AttributedString(s)
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return a }
        var from = s.startIndex
        while let r = s.range(of: q, options: [.caseInsensitive, .diacriticInsensitive], range: from..<s.endIndex) {
            if let ar = Range(r, in: a) { a[ar].backgroundColor = Color.yellow.opacity(0.45) }
            from = r.upperBound
        }
        return a
    }

    /// A short excerpt around the first match, with … where it was cut.
    static func snippet(_ s: String, _ query: String, radius: Int = 40) -> String? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, let r = s.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
        let start = s.index(r.lowerBound, offsetBy: -radius, limitedBy: s.startIndex) ?? s.startIndex
        let end = s.index(r.upperBound, offsetBy: radius, limitedBy: s.endIndex) ?? s.endIndex
        let core = s[start..<end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return (start > s.startIndex ? "…" : "") + core + (end < s.endIndex ? "…" : "")
    }

    static func matches(_ s: String?, _ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return s?.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

extension Format {
    /// "notes.example.com/canvas?x=1": no scheme and no "www.", for lists where space is tight.
    static func shortURL(_ s: String) -> String {
        var t = s
        for prefix in ["https://", "http://", "www."] where t.hasPrefix(prefix) { t.removeFirst(prefix.count) }
        if t.hasSuffix("/") { t.removeLast() }
        return t
    }
}

/// Width ÷ height of an image file, read from its header (no decode), so a placeholder can take the
/// image's exact shape and nothing moves when the picture arrives.
@MainActor
enum ImageAspect {
    private static var cache: [String: CGFloat] = [:]

    static func of(_ url: URL, revision: Int = 0) -> CGFloat {
        let key = "\(url.path)#\(revision)"
        if let hit = cache[key] { return hit }
        var aspect: CGFloat = 16 / 10
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
           let w = (p[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
           let h = (p[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue, w > 0, h > 0 {
            aspect = w / h
        }
        cache[key] = aspect
        return aspect
    }
}

/// Lays its content out at a fixed aspect ratio, as wide as offered but never taller than `maxHeight`,
/// pinned to the leading edge. A tall screenshot stays a readable column instead of filling the panel.
struct FitBox: Layout {
    var aspect: CGFloat
    var maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widest = maxHeight * aspect
        let w = min(proposal.width ?? widest, widest)
        return CGSize(width: w, height: w / aspect)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for s in subviews { s.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size)) }
    }
}
