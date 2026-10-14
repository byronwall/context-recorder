import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Marking up a recording after the fact: marks and region shots taken from the video, plus notes.
///
/// Review marks are appended to marks.jsonl with `"source": "review"`, then the session is re-processed
/// with scripts/process_session.py like any other, so frames, narration, Markdown and export all treat
/// them the same as marks made while recording. They carry what the recording knows at that moment:
/// app, window and URL from the activity log, narration, and the page events just before. There is no
/// live Chrome snapshot (element under the pointer, saved page).
extension SessionModel {
    /// M: a mark at the playhead.
    func addReviewMark() async {
        await addReview(region: nil, shot: false)
    }

    /// S: a region shot. `region` is normalized to the video (0…1, top-left origin); nil = whole frame.
    func addReviewShot(region: CGRect?) async {
        await addReview(region: region, shot: true)
    }

    private func addReview(region: CGRect?, shot: Bool) async {
        player.pause()
        let t = currentTime
        reviewStatus = shot ? "Saving shot…" : "Adding mark…"
        defer { reviewStatus = nil }
        do {
            var lines = try MarksFile.load(folder)
            let index = (lines.compactMap { $0["index"]?.numberValue.map(Int.init) }.max() ?? 0) + 1
            var mark: [String: JSONValue] = [
                "index": .number(Double(index)),
                "kind": .string(shot ? "screenshot" : "mark"),
                "offsetSeconds": .number((t * 1000).rounded() / 1000),
                "wallTime": .string(wallTime(at: t)),
                "source": .string("review"),
                "context": contextJSON(at: t),
            ]
            let recent = recentPageEvents(before: t)
            if !recent.isEmpty { mark["browser"] = .object(["recent": .array(recent)]) }
            if shot {
                let name = String(format: "screenshots/%03d.png", index)
                let size = try await saveFrame(at: t, crop: region, to: folder.appendingPathComponent(name))
                mark["screenshot"] = .string(name)
                if let region {
                    mark["region"] = .object([
                        "x": .number((region.minX * size.width).rounded()), "y": .number((region.minY * size.height).rounded()),
                        "width": .number((region.width * size.width).rounded()), "height": .number((region.height * size.height).rounded()),
                        "space": .string("video"),
                    ])
                }
            }
            lines.append(.object(mark))
            try MarksFile.save(lines, to: folder)
            focusNoteFor = index
            pendingSelect = index
            try await reprocess()
        } catch {
            reviewError = error.localizedDescription
        }
    }

    func setNote(_ note: String, for index: Int) async {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (mark(index)?.note ?? "") != trimmed else { return }
        reviewStatus = "Saving note…"
        defer { reviewStatus = nil }
        do {
            var lines = try MarksFile.load(folder)
            guard let i = lines.firstIndex(where: { $0["index"]?.numberValue == Double(index) }) else { return }
            lines[i] = lines[i].setting("note", trimmed.isEmpty ? .null : .string(trimmed))
            try MarksFile.save(lines, to: folder)
            try await reprocess()
        } catch {
            reviewError = error.localizedDescription
        }
    }

    /// Only review marks can be deleted; marks made while recording are the source data.
    func deleteReviewMark(_ index: Int) async {
        guard mark(index)?.isReview == true else { return }
        reviewStatus = "Deleting mark…"
        defer { reviewStatus = nil }
        do {
            let lines = try MarksFile.load(folder).filter { $0["index"]?.numberValue != Double(index) }
            try MarksFile.save(lines, to: folder)
            // Frames are cached by index; remove them so a later mark can't pick up this one's image.
            for file in [String(format: "screenshots/%03d.png", index), String(format: "frames/%03d.jpg", index)] {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
                AnnotationStore(folder: folder).remove(file)
            }
            if selectedMark == index { selectedMark = nil }
            try await reprocess()
        } catch {
            reviewError = error.localizedDescription
        }
    }

    /// The image viewer saved annotations: re-process so Markdown, session.md and export pick up the
    /// marked-up copies.
    func annotationsChanged() {
        if annotationPass != nil { annotationPassAgain = true; return }
        annotationPass = Task {
            repeat {
                annotationPassAgain = false
                reviewStatus = "Saving annotations…"
                do { try await reprocess() } catch { reviewError = error.localizedDescription }
            } while annotationPassAgain
            annotationRevision += 1
            reviewStatus = nil
            annotationPass = nil
        }
    }

    // MARK: Pieces

    private func contextJSON(at t: Double) -> JSONValue {
        guard let ctx = contextAt(t), let data = try? JSONEncoder().encode(ctx),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data) else { return .object([:]) }
        return value
    }

    /// Page events from the 30 s before the mark, as recorded (so problems show up like on live marks).
    private func recentPageEvents(before t: Double) -> [JSONValue] {
        guard let raw = try? String(contentsOf: folder.appendingPathComponent("browser.jsonl"), encoding: .utf8) else { return [] }
        return raw.split(separator: "\n").compactMap { line -> JSONValue? in
            guard let v = try? JSONDecoder().decode(JSONValue.self, from: Data(line.utf8)),
                  let offset = v["offsetSeconds"]?.numberValue, offset <= t, offset >= t - 30 else { return nil }
            return v["event"]
        }.suffix(40)
    }

    private func wallTime(at t: Double) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        let start = f.date(from: folder.lastPathComponent) ?? .now
        return ISO8601DateFormatter().string(from: start.addingTimeInterval(t))
    }

    /// Writes the video frame at `t` (cropped to the normalized region) as PNG; returns the frame's pixel size.
    private func saveFrame(at t: Double, crop: CGRect?, to url: URL) async throws -> CGSize {
        let asset = AVURLAsset(url: folder.appendingPathComponent("recording.mp4"))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (frame, _) = try await generator.image(at: CMTime(seconds: t, preferredTimescale: 600))
        let size = CGSize(width: frame.width, height: frame.height)
        var image = frame
        if let crop {
            let rect = CGRect(x: crop.minX * size.width, y: crop.minY * size.height,
                              width: crop.width * size.width, height: crop.height * size.height).integral
            image = frame.cropping(to: rect) ?? frame
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ReviewError("Couldn't write \(url.lastPathComponent)")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ReviewError("Couldn't write \(url.lastPathComponent)") }
        return size
    }

    /// Re-runs scripts/process_session.py (frames, narration, Markdown, session.json), then reloads.
    func reprocess() async throws {
        guard let script = AppDelegate.processScriptURL() else { throw ReviewError("process_session.py wasn't found") }
        let folder = self.folder
        let status: Int32 = try await withCheckedThrowingContinuation { cont in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // Login shell so PATH includes ffmpeg; same as after a recording.
            process.arguments = ["-lc", "python3 \"$0\" \"$1\" >> \"$1/process.log\" 2>&1", script.path, folder.path]
            process.terminationHandler = { cont.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
        guard status == 0 else { throw ReviewError("Processing failed; see process.log in the session folder") }
        reload()
        if let index = pendingSelect, mark(index) != nil {
            pendingSelect = nil
            tab = .marks
            markFilter = .all
            select(index, seek: false)
        }
    }
}

struct ReviewError: LocalizedError {
    var message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// marks.jsonl as loose JSON, so fields this app doesn't model survive a rewrite.
enum MarksFile {
    static func url(_ folder: URL) -> URL { folder.appendingPathComponent("marks.jsonl") }

    static func load(_ folder: URL) throws -> [JSONValue] {
        guard FileManager.default.fileExists(atPath: url(folder).path) else { return [] }
        return try String(contentsOf: url(folder), encoding: .utf8)
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { try JSONDecoder().decode(JSONValue.self, from: Data($0.utf8)) }
    }

    static func save(_ lines: [JSONValue], to folder: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let text = try lines.map { String(decoding: try enc.encode($0), as: UTF8.self) }.joined(separator: "\n") + "\n"
        try text.write(to: url(folder), atomically: true, encoding: .utf8)
    }
}
