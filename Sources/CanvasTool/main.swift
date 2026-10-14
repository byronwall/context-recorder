import CanvasKit
import Foundation

let usage = """
canvas-tool: build and check Context Recorder canvases.

  canvas-tool check [--fixtures DIR] [--regen] [--only a,b] [--storyboard]
      Generate synthetic clips if missing, analyze each, check against known answers. Exit 1 on failure.
  canvas-tool fixtures [--fixtures DIR] [--only a,b]
      (Re)generate the synthetic clips.
  canvas-tool analyze SESSION_FOLDER [--box x,y,w,h] [--storyboard]
      Build canvas.json for a session (the same code the app runs).

--storyboard turns off scroll joining (cards only).
Default fixtures folder: tmp/canvas-fixtures
"""

func value(_ flag: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

let args = Array(CommandLine.arguments.dropFirst())
let fixtures = URL(fileURLWithPath: value("--fixtures", in: args) ?? "tmp/canvas-fixtures")
let only = value("--only", in: args).map { Set($0.split(separator: ",").map(String.init)) }
var options = CanvasAnalyzer.Options()
if args.contains("--storyboard") { options.joinScrolling = false }

do {
    switch args.first {
    case "fixtures":
        print("Writing fixtures to \(fixtures.path)")
        try await Fixtures.write(to: fixtures, only: only)
    case "check":
        let missing = Fixtures.clips().contains { clip in
            (only?.contains(clip.name) ?? true)
                && !FileManager.default.fileExists(atPath: fixtures.appendingPathComponent("\(clip.name)/truth.json").path)
        }
        if args.contains("--regen") || missing {
            print("Writing fixtures to \(fixtures.path)")
            try await Fixtures.write(to: fixtures, only: only)
        }
        let results = try await Check.run(root: fixtures, only: only, options: options)
        exit(Check.report(results) ? 0 : 1)
    case "analyze":
        guard args.count > 1 else { print(usage); exit(2) }
        let folder = URL(fileURLWithPath: args[1])
        var box: PixelRect?
        if let b = value("--box", in: args) {
            let n = b.split(separator: ",").compactMap { Int($0) }
            guard n.count == 4 else { print("--box needs x,y,w,h"); exit(2) }
            box = PixelRect(x: n[0], y: n[1], width: n[2], height: n[3])
        }
        let started = Date()
        let doc = try await CanvasAnalyzer.build(folder: folder, box: box, options: options)
        let cols = doc.items.filter { $0.kind == .column }.count
        print(String(format: "%d items (%d columns, %d cards) from %d frames in %.1fs",
                     doc.items.count, cols, doc.items.count - cols, doc.video.frameCount, Date().timeIntervalSince(started)))
    default:
        print(usage)
        exit(args.isEmpty ? 0 : 2)
    }
} catch {
    print("error: \(error.localizedDescription)")
    exit(1)
}
