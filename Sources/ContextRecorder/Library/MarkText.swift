import Foundation

/// Titles, narration splitting and the "Copy as Markdown" text for marks.
enum MarkText {
    static let flag: Character = "⚑"

    /// Split on sentence ends (. ! ?) followed by whitespace, like the viewer's /(?<=[.!?])\s+/.
    static func sentences(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        var chars = Array(text)[...]
        while let c = chars.popFirst() {
            current.append(c)
            if ".!?".contains(c), let next = chars.first, next.isWhitespace {
                while let n = chars.first, n.isWhitespace { chars.removeFirst() }
                out.append(current)
                current = ""
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { out.append(current) }
        return out.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func withoutFlag(_ s: String) -> String {
        s.replacingOccurrences(of: String(flag), with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .replacingOccurrences(of: " ,", with: ",").replacingOccurrences(of: " .", with: ".")
    }

    /// The narration split around the mark: the sentence that contains ⚑ is the focus.
    struct Narration {
        var before: [String]
        var focusLead: String    // focus sentence up to the mark
        var focusTail: String    // focus sentence after the mark
        var after: [String]
        var focus: String { withoutFlag(focusLead + " " + focusTail) }
    }

    static func narration(_ text: String?) -> Narration? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var parts = sentences(text)
        guard var i = parts.firstIndex(where: { $0.contains(flag) }) else {
            return Narration(before: parts, focusLead: "", focusTail: "", after: [])
        }
        // "…broken. ⚑" leaves the flag on its own: attach it to the end of the previous sentence.
        if withoutFlag(parts[i]).isEmpty, i > 0 {
            parts[i - 1] += " " + String(flag)
            parts.remove(at: i)
            i -= 1
        }
        let pieces = parts[i].split(separator: flag, maxSplits: 1, omittingEmptySubsequences: false)
        return Narration(before: Array(parts[..<i]),
                         focusLead: String(pieces[0]).trimmingCharacters(in: .whitespaces),
                         focusTail: pieces.count > 1 ? String(pieces[1]).trimmingCharacters(in: .whitespaces) : "",
                         after: Array(parts[(i + 1)...]))
    }

    /// The sentence being spoken when the mark was made; falls back to page, window, app.
    static func title(_ m: SessionMark) -> String {
        if let note = noteTitle(m.note) { return note }
        if let n = narration(m.narration) {
            let focus = n.focus
            if !focus.isEmpty { return focus }
            if let last = n.before.last { return withoutFlag(last) }
        }
        let c = m.context
        return [c?.browserTitle, c?.windowTitle, c?.appName].compactMap { $0.nonEmpty }.first ?? "Mark \(m.index)"
    }

    /// First line of a typed note.
    static func noteTitle(_ note: String?) -> String? {
        guard let line = note?.split(whereSeparator: \.isNewline).first?.trimmingCharacters(in: .whitespaces), !line.isEmpty else { return nil }
        return line
    }

    // MARK: Markdown (keep in step with markdownFor() in scripts/viewer.html)

    static func markdown(_ m: SessionMark, folder: String) -> String {
        let c = m.context
        let b = m.browser
        var lines: [String] = [
            "## \(String(format: "%03d", m.index)) · \(Format.time(m.offsetSeconds)) · \(title(m))",
            "", "![mark \(m.index)](\(m.image ?? ""))", "",
        ]
        if let note = m.note.nonEmpty { lines.append("**Note:** \(note.split(whereSeparator: \.isWhitespace).joined(separator: " "))\n") }
        lines.append(m.narration.nonEmpty.map { "> \($0)\n" } ?? "")
        if let app = c?.appName.nonEmpty { lines.append("- **App:** \(app) (`\(c?.bundleID ?? "undefined")`)") }
        if let w = c?.windowTitle.nonEmpty { lines.append("- **Window:** \(w)") }
        if let u = c?.browserURL.nonEmpty { lines.append("- **URL:** \(u)") }
        if let t = c?.browserTitle.nonEmpty { lines.append("- **Page title:** \(t)") }
        lines.append("- **Video:** `\(folder)/recording.mp4` @ \(String(format: "%.1f", m.offsetSeconds))s")
        if m.isReview { lines.append("- **Added:** while reviewing the recording (no live page snapshot)") }
        if let h = b?.hovered {
            var line = "- **Under mouse:** `\(h.selector ?? "")`"
            if let t = h.text.nonEmpty { line += " “\(t)”" }
            if h.components != nil { line += " in " + h.componentPath.joined(separator: " › ") }
            lines.append(line)
            if let src = h.source { lines.append("- **Source:** `\(sourceText(src))`") }
        }
        if let f = b?.focused { lines.append("- **Focused:** `\(f.selector ?? "")`") }
        for el in (b?.region?.elements ?? []).prefix(15) {
            var line = "- In region: `\(el.selector ?? "")`"
            if let t = el.text.nonEmpty { line += " “\(String(t.prefix(80)))”" }
            if let src = el.source { line += " · \(sourceText(src))" }
            lines.append(line)
        }
        if let page = b?.pageFile.nonEmpty { lines.append("- **Saved page:** `\(folder)/\(page)`") }
        for e in (b?.recent ?? []).filter(\.isProblem).suffix(8) { lines.append("- ⚠ \(e.summary)") }
        return lines.joined(separator: "\n")
    }

    static func markdown(session: SessionData, folder: String) -> String {
        "# Session \(session.name)\n\n" + session.marks.map { markdown($0, folder: folder) }.joined(separator: "\n\n")
    }

    /// sourceText() in viewer.html.
    static func sourceText(_ s: SourceLocation) -> String {
        guard let loc = s.location else { return "" }
        return loc + (s.isPostTransform ? " (post-transform line)" : "")
    }
}

extension Optional where Wrapped == String {
    /// nil for nil or "", so JS-style truthiness checks port directly.
    var nonEmpty: String? {
        guard let s = self, !s.isEmpty else { return nil }
        return s
    }
}
