import AppKit
import Foundation

/// Headless commands (no window, no menu-bar item):
///   ContextRecorder --cloud-bundle <session> <out-folder>
///   ContextRecorder --push <session> [--cloud <url>]
///   ContextRecorder --self-test cloud-bundle | cloud-client
/// Exit codes: 0 ok, 1 failed, 2 bad usage or no cloud configured.
@MainActor
enum CloudCLI {
    static func handles(_ args: [String]) -> Bool {
        args.contains("--cloud-bundle") || args.contains("--push") || ["cloud-bundle", "cloud-client"].contains(value(args, "--self-test") ?? "")
    }

    /// Runs the command on the main actor and exits; the caller then parks the main thread in dispatchMain().
    static func start(_ args: [String]) {
        // ImageRenderer and AppKit text measuring want an NSApplication, but it never shows anything.
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        Task { @MainActor in
            let code = await run(args)
            fflush(stdout)
            exit(code)
        }
    }

    static func run(_ args: [String]) async -> Int32 {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        func path(_ s: String) -> URL { URL(fileURLWithPath: (s as NSString).expandingTildeInPath, relativeTo: cwd).standardizedFileURL }
        switch value(args, "--self-test") {
        case "cloud-bundle":
            let fixture = cwd.appendingPathComponent("scripts/fixtures/cloud-bundle-cases.json")
            let failures = await CloudSelfTest.runBundle(fixture: fixture, keep: args.contains("--keep"))
            for f in failures { fputs("FAIL \(f)\n", stderr) }
            print(failures.isEmpty ? "Cloud bundle checks passed" : "Cloud bundle checks failed: \(failures.count)")
            return failures.isEmpty ? 0 : 1
        case "cloud-client":
            let failures = await CloudSelfTest.runClient()
            for f in failures { fputs("FAIL \(f)\n", stderr) }
            print(failures.isEmpty ? "Cloud client checks passed" : "Cloud client checks failed: \(failures.count)")
            return failures.isEmpty ? 0 : 1
        default: break
        }

        if let i = args.firstIndex(of: "--cloud-bundle") {
            guard i + 2 < args.count else {
                fputs("usage: ContextRecorder --cloud-bundle <session-folder> <out-folder>\n", stderr)
                return 2
            }
            let session = path(args[i + 1]), out = path(args[i + 2])
            do {
                let start = Date()
                let manifest = try await CloudBundle.build(session: session, to: out) { phase, f in
                    fputs(String(format: "  %3.0f%%  %@\n", f * 100, phase), stderr)
                }
                let total = manifest.files.reduce(Int64(0)) { $0 + $1.size }
                let drawings = (try? Data(contentsOf: out.appendingPathComponent("drawings.json")))
                    .flatMap { try? JSONDecoder().decode([CloudDrawing].self, from: $0) } ?? []
                print("Wrote \(out.path)")
                print("  session \(manifest.sessionId) · \(Format.time(manifest.duration)) (\(manifest.duration) s) · \(manifest.markCount) marks · \(drawings.count) drawing windows")
                print("  video \(manifest.video.width)x\(manifest.video.height) · \(manifest.thumbs.count) thumbs · \(manifest.files.count) files · \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
                if !manifest.skippedPages.isEmpty { print("  skipped pages: " + manifest.skippedPages.map(\.path).joined(separator: ", ")) }
                print("  inputHash \(manifest.inputHash)")
                print(String(format: "  %.1f s · open %@", Date().timeIntervalSince(start), out.appendingPathComponent("index.html").path))
                return 0
            } catch {
                fputs("cloud-bundle failed: \(error.localizedDescription)\n", stderr)
                return 1
            }
        }

        if let i = args.firstIndex(of: "--push") {
            guard i + 1 < args.count, !args[i + 1].hasPrefix("--") else {
                fputs("usage: ContextRecorder --push <session-folder> [--cloud <url>]\n", stderr)
                return 2
            }
            let session = path(args[i + 1])
            guard let config = CloudConfig.current(override: value(args, "--cloud")) else {
                fputs("No cloud configured: pass --cloud <url>, set CR_CLOUD_URL, or set it in Cloud Settings.\n", stderr)
                return 2
            }
            do {
                var last = ""
                let (record, report) = try await CloudPush.run(session: session, config: config) { phase, f in
                    let line = String(format: "  %3.0f%%  %@", f * 100, phase)
                    if line != last { fputs(line + "\n", stderr); last = line }
                }
                print("Pushed \(session.lastPathComponent) → \(record.url)")
                print("  uploaded \(report.uploaded.count) files (\(ByteCountFormatter.string(fromByteCount: report.uploadedBytes, countStyle: .file)))"
                      + (report.multipart.isEmpty ? "" : ", in parts: " + report.multipart.joined(separator: ", ")))
                print("  manifestSha256 \(record.manifestSha256)")
                print("  wrote \(CloudRecord.url(session).path)")
                return 0
            } catch {
                fputs("push failed: \(error.localizedDescription)\n", stderr)
                return 1
            }
        }
        return 2
    }

    private static func value(_ args: [String], _ flag: String) -> String? {
        args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
    }
}
