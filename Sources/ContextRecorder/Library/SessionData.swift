import Foundation

/// `session.json`, written by scripts/process_session.py. Every field is optional except the basics so
/// older or half-processed sessions still load.
struct SessionData: Decodable {
    var name: String
    var folder: String?
    var duration: Double?
    var marks: [SessionMark]
    var activity: [ActivityEntry]
    var browser: [BrowserEntry]
    var transcript: [Sentence]

    enum CodingKeys: String, CodingKey { case name, folder, duration, marks, activity, browser, transcript }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        folder = try c.decodeIfPresent(String.self, forKey: .folder)
        duration = try c.decodeIfPresent(Double.self, forKey: .duration)
        marks = try c.decodeIfPresent([SessionMark].self, forKey: .marks) ?? []
        activity = try c.decodeIfPresent([ActivityEntry].self, forKey: .activity) ?? []
        browser = try c.decodeIfPresent([BrowserEntry].self, forKey: .browser) ?? []
        transcript = try c.decodeIfPresent([Sentence].self, forKey: .transcript) ?? []
    }
}

struct SessionMark: Decodable, Identifiable, Hashable {
    var index: Int
    var kind: String              // "mark" | "screenshot"
    var offsetSeconds: Double
    var wallTime: String?
    var image: String?            // screenshot when it exists, else the video frame
    var frame: String?
    var screenshot: String?
    var narration: String?        // spoken window around the mark, with ⚑ where the mark landed
    var context: MarkContext?
    var browser: PageSnapshot?

    var id: Int { index }
    var isShot: Bool { kind == "screenshot" }

    static func == (a: SessionMark, b: SessionMark) -> Bool { a.index == b.index && a.offsetSeconds == b.offsetSeconds }
    func hash(into h: inout Hasher) { h.combine(index) }
}

struct ActivityEntry: Decodable {
    var offsetSeconds: Double
    var context: MarkContext?
}

struct BrowserEntry: Decodable {
    var offsetSeconds: Double
    var event: PageEvent
}

struct Sentence: Decodable, Hashable {
    var start: Double
    var end: Double
    var text: String
}

/// What the Chrome extension saw at the mark.
struct PageSnapshot: Decodable {
    var url: String?
    var title: String?
    var hovered: PageElement?
    var focused: PageElement?
    var selection: String?
    var recent: [PageEvent]?
    var region: RegionElements?
    var pageFile: String?
    var pageError: String?
    var error: String?
}

struct PageElement: Decodable, Hashable {
    var selector: String?
    var tag: String?
    var text: String?
    var components: [String]?
    var source: SourceLocation?
    var props: ComponentProps?

    /// Outermost → innermost, as breadcrumbs read. The extension stores innermost first.
    var componentPath: [String] { Array((components ?? []).prefix(5).reversed()) }

    static func == (a: PageElement, b: PageElement) -> Bool { a.selector == b.selector && a.text == b.text }
    func hash(into h: inout Hasher) { h.combine(selector); h.combine(text) }
}

struct SourceLocation: Decodable {
    var file: String?
    var line: Int?
    var column: Int?
    var via: String?

    /// `file:line:column`, matching sourceText() in viewer.html (without its post-transform note).
    var location: String? {
        guard let file, !file.isEmpty else { return nil }
        return file + (line.map { ":\($0)" } ?? "") + (column.map { ":\($0)" } ?? "")
    }
    /// React 19 stacks point into the transformed module, so the line can be off.
    var isPostTransform: Bool { via == "react-debugStack" }
}

struct ComponentProps: Decodable {
    var component: String?
    var props: [String: JSONValue]?
}

struct RegionElements: Decodable {
    var method: String?
    var elements: [PageElement]?
    var note: String?
}

/// One page event from the extension. `kind` is click | nav | console | error | request.
struct PageEvent: Decodable {
    var kind: String
    var element: PageElement?
    var how: String?
    var url: String?
    var level: String?
    var message: String?
    var type: String?
    var source: String?
    var method: String?
    var requestUrl: String?
    var status: Int?
    var ms: Double?
    var error: String?
    var body: String?
    var slow: Bool?

    enum CodingKeys: String, CodingKey {
        case kind, element, how, url, level, message, type, source, method, requestUrl, status, ms, error, body, slow
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? "event"
        element = try? c.decodeIfPresent(PageElement.self, forKey: .element)
        how = try? c.decodeIfPresent(String.self, forKey: .how)
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        level = try? c.decodeIfPresent(String.self, forKey: .level)
        message = Self.text(c, .message)
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        source = Self.text(c, .source)
        method = try? c.decodeIfPresent(String.self, forKey: .method)
        requestUrl = try? c.decodeIfPresent(String.self, forKey: .requestUrl)
        status = (try? c.decodeIfPresent(Double.self, forKey: .status)).flatMap { $0.map(Int.init) }
        ms = try? c.decodeIfPresent(Double.self, forKey: .ms)
        error = Self.text(c, .error)
        body = Self.text(c, .body)
        slow = try? c.decodeIfPresent(Bool.self, forKey: .slow)
    }

    /// Strings that the page may have sent as something else (numbers, objects).
    private static func text(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        guard let v = try? c.decodeIfPresent(JSONValue.self, forKey: key) else { return nil }
        return v.compactText
    }

    /// Same rule as isProblem() in viewer.html and process_session.py.
    var isProblem: Bool {
        switch kind {
        case "console", "error": return true
        case "request": return error != nil || (status ?? 0) >= 400 || status == 0 || slow == true
        default: return false
        }
    }

    /// One-line description, identical to pageEventText() in viewer.html.
    var summary: String {
        switch kind {
        case "click":
            return "click \(element?.selector ?? "")" + (element?.text.map { " “\($0)”" } ?? "")
        case "nav": return "\(how ?? "") → \(url ?? "")"
        case "console": return "console.\(level ?? ""): \(message ?? "")"
        case "error": return "\(type ?? ""): \(message ?? source ?? "")"
        case "request":
            return "\(method ?? "") \(requestUrl ?? "") → \(status.map(String.init) ?? "") (\(ms.map(Format.number) ?? "") ms)"
                + (error.map { " " + $0 } ?? "") + (body.map { " — " + $0 } ?? "")
        default: return kind
        }
    }
}

extension JSONValue {
    /// Short inline rendering, like JSON.stringify for scalars and objects.
    var compactText: String {
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return Format.number(n)
        case .string(let s): return s
        default:
            let enc = JSONEncoder()
            enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return (try? enc.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
    }

    /// JSON.stringify(value): strings get quotes.
    var jsonText: String {
        if case .string(let s) = self {
            let enc = JSONEncoder()
            enc.outputFormatting = [.withoutEscapingSlashes]
            return (try? enc.encode(s)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\(s)\""
        }
        return compactText
    }
}

enum Format {
    /// `m:ss`, same as fmt() in viewer.html.
    static func time(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.isFinite ? seconds : 0))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// JavaScript-style number text: 120 not 120.0.
    static func number(_ n: Double) -> String {
        n.rounded() == n && abs(n) < 1e15 ? String(Int(n)) : String(n)
    }
}
