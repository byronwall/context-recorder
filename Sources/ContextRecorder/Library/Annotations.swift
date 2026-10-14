import AppKit
import SwiftUI

/// A drawing on top of the video: RegionShot's tools (rectangle, arrow, text, highlight, freehand).
/// Positions are fractions of the video frame (0…1, top-left origin) so they stay put at any window size.
/// Times are in the *source* recording, like marks, so cuts and joins never move an annotation off its
/// moment; one that spans a cut is hidden only while the cut part would have played.
struct Annotation: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable { case rectangle, arrow, text, highlight, pen }

    var id = UUID()
    var kind: Kind
    var source = "."
    var start: Double
    var end: Double
    /// rectangle, highlight: two corners. arrow: tail, head. text: top-left and top-right (wrap width).
    /// pen: the stroke.
    var points: [CGPoint]
    var color: String
    var text: String?

    var bounds: CGRect {
        guard let first = points.first else { return .null }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    func moved(by d: CGSize) -> Annotation {
        var a = self
        a.points = points.map { CGPoint(x: $0.x + d.width, y: $0.y + d.height) }
        return a
    }

    /// Default on-screen time for a new annotation.
    static let defaultSpan = 3.0
}

/// The tools in draw mode, with RegionShot's keys.
enum AnnotationTool: String, CaseIterable, Identifiable {
    case select, rectangle, arrow, text, highlight, pen
    var id: String { rawValue }

    /// The tools offered in draw mode.
    static let available: [AnnotationTool] = allCases

    var kind: Annotation.Kind? {
        switch self {
        case .select: nil
        case .rectangle: .rectangle
        case .arrow: .arrow
        case .text: .text
        case .highlight: .highlight
        case .pen: .pen
        }
    }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .rectangle: "rectangle"
        case .arrow: "arrow.up.right"
        case .text: "textformat"
        case .highlight: "highlighter"
        case .pen: "scribble"
        }
    }

    var key: Character {
        switch self {
        case .select: "s"
        case .rectangle: "r"
        case .arrow: "a"
        case .text: "t"
        case .highlight: "h"
        case .pen: "d"
        }
    }

    var title: String {
        switch self {
        case .select: "Select"
        case .rectangle: "Rectangle"
        case .arrow: "Arrow"
        case .text: "Text"
        case .highlight: "Highlight"
        case .pen: "Draw"
        }
    }
}

enum AnnotationPalette {
    static let colors = ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#AF52DE", "#000000", "#FFFFFF"]
    static let defaultStroke = "#FF3B30"
    static let defaultHighlight = "#FFCC00"

    static func color(_ hex: String) -> Color { Color(nsColor: nsColor(hex)) }

    static func nsColor(_ hex: String) -> NSColor {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return .systemRed }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    /// Black or white, whichever reads on `hex`.
    static func textColor(on hex: String) -> Color {
        let c = nsColor(hex).usingColorSpace(.sRGB) ?? .black
        let luma = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return luma > 0.6 ? .black : .white
    }
}

/// annotations.json in the session folder.
enum AnnotationsFile {
    static func url(_ folder: URL) -> URL { folder.appendingPathComponent("annotations.json") }

    static func load(_ folder: URL) -> [Annotation] {
        struct File: Decodable { var annotations: [Annotation] }
        guard let data = try? Data(contentsOf: url(folder)), let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.annotations
    }

    static func save(_ annotations: [Annotation], to folder: URL) throws {
        guard !annotations.isEmpty else {
            try? FileManager.default.removeItem(at: url(folder))
            return
        }
        struct File: Encodable { var annotations: [Annotation] }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try enc.encode(File(annotations: annotations)).write(to: url(folder), options: .atomic)
    }
}

extension EditMap {
    /// The parts of source range a…b that survive, in edited time.
    func editedPieces(source: String, _ a: Double, _ b: Double) -> [ClosedRange<Double>] {
        segments.compactMap { s in
            guard s.source == source else { return nil }
            let lo = max(a, s.start), hi = min(b, s.end)
            guard hi > lo else { return nil }
            let es = s.editedStart ?? 0
            return (es + lo - s.start)...(es + hi - s.start)
        }
    }
}

// MARK: - The session's annotations

extension SessionModel {
    /// Annotations on screen at an edited time.
    func annotations(at edited: Double) -> [Annotation] {
        let p = sourcePoint(edited)
        return annotations.filter { $0.source == p.source && $0.start <= p.time && p.time <= $0.end }
    }

    /// Where an annotation shows in edited time (more than one piece when a cut runs through it).
    func editedPieces(_ a: Annotation) -> [ClosedRange<Double>] {
        if let edits { return edits.editedPieces(source: a.source, a.start, a.end) }
        return a.source == "." ? [a.start...a.end] : []
    }

    /// A new annotation at the playhead, shown for `Annotation.defaultSpan` seconds.
    func newAnnotation(_ kind: Annotation.Kind, points: [CGPoint], text: String? = nil) -> Annotation {
        let p = sourcePoint(currentTime)
        let limit = sourceDurations[p.source] ?? .infinity
        let color = kind == .highlight ? highlightColor : annotationColor
        return Annotation(kind: kind, source: p.source, start: p.time, end: min(limit, p.time + Annotation.defaultSpan),
                          points: points, color: color, text: text)
    }

    /// Replaces the annotations (one undo step) and saves annotations.json.
    func setAnnotations(_ next: [Annotation], undoable: Bool = true) {
        guard next != annotations else { return }
        if undoable {
            undoStack.append(.annotations(annotations))
            redoStack = []
        }
        annotations = next
        if let id = selectedAnnotation, !next.contains(where: { $0.id == id }) { selectedAnnotation = nil }
        do { try AnnotationsFile.save(next, to: folder) } catch {
            reviewError = "annotations.json couldn't be saved: \(error.localizedDescription)"
        }
    }

    func updateAnnotation(_ a: Annotation) {
        setAnnotations(annotations.map { $0.id == a.id ? a : $0 })
    }

    func addAnnotation(_ a: Annotation) {
        setAnnotations(annotations + [a])
        selectedAnnotation = a.id
    }

    func deleteSelectedAnnotation() {
        guard let id = selectedAnnotation else { return }
        setAnnotations(annotations.filter { $0.id != id })
        selectedAnnotation = nil
    }

    /// Changing the color recolors the selected annotation too, like RegionShot.
    func setColor(_ hex: String) {
        if let id = selectedAnnotation, let a = annotations.first(where: { $0.id == id }) {
            if a.kind == .highlight { highlightColor = hex } else { annotationColor = hex }
            var changed = a
            changed.color = hex
            updateAnnotation(changed)
        } else if tool == .highlight {
            highlightColor = hex
        } else {
            annotationColor = hex
        }
    }

    func enterDrawMode(_ on: Bool) {
        drawMode = on
        if on {
            player.pause()
            regionMode = false
            selection = nil
        } else {
            selectedAnnotation = nil
            editingText = nil
            tool = .select
        }
    }

    /// Moves one end of an annotation's time span to an edited time (from its timeline bar).
    func setAnnotationSpan(_ id: UUID, startEdited: Double?, endEdited: Double?) {
        guard var a = annotations.first(where: { $0.id == id }) else { return }
        if let e = startEdited { let p = sourcePoint(e); if p.source == a.source { a.start = min(p.time, a.end - 0.2) } }
        if let e = endEdited { let p = sourcePoint(e); if p.source == a.source { a.end = max(p.time, a.start + 0.2) } }
        updateAnnotation(a)
    }
}
