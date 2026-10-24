import AppKit
import Foundation

/// Headless commands (no window, no menu-bar item):
///   ContextRecorder --cloud-bundle <session> <out-folder>
///   ContextRecorder --push <session> [--cloud <url>]
///   ContextRecorder --cloud-list [--cloud <url>]
///   ContextRecorder --pull <session-id> [--cloud <url>] [--into <library-folder>]
///   ContextRecorder --self-test cloud-bundle | cloud-client
/// `--push`, `--cloud-list` and `--pull` use the app's stored sign-in; `CR_CLOUD_TOKEN` (an access token) overrides it.
/// Exit codes: 0 ok, 1 failed, 2 bad usage, no cloud configured, or signed out.
@MainActor
enum CloudCLI {
    static func handles(_ args: [String]) -> Bool {
        ["--cloud-bundle", "--push", "--cloud-list", "--pull"].contains(where: args.contains) || ["cloud-bundle", "cloud-client"].contains(value(args, "--self-test") ?? "")
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

        // Every remaining command talks to the cloud.
        func cloudConfig() -> CloudConfig? {
            guard let config = CloudConfig.current(override: value(args, "--cloud")) else {
                fputs("No cloud configured: pass --cloud <url>, set CR_CLOUD_URL, or set it in Cloud Settings.\n", stderr)
                return nil
            }
            // A local wrangler dev Worker (DEV_IDENTITY) takes requests without a token.
            guard CloudAuth.isLocal(config.url) || config.hasCredentials else {
                fputs("Not signed in to \(config.url.absoluteString). Sign in from Cloud Settings in the app, or set CR_CLOUD_TOKEN.\n", stderr)
                return nil
            }
            return config
        }

        if args.contains("--cloud-list") {
            guard let config = cloudConfig() else { return 2 }
            do {
                let rows = try await config.client.listSessions()
                let local = Set(SessionLibrary.sessionFolders(in: Session.root).map(\.lastPathComponent))
                for r in rows {
                    let size = ByteCountFormatter.string(fromByteCount: r.size, countStyle: .file)
                    print("\(local.contains(r.id) ? "here " : "cloud") \(r.id)  \(r.title)  \(Format.time(r.duration))  \(size)  from \(r.machine ?? "?")")
                }
                return 0
            } catch {
                fputs("cloud-list failed: \(error.localizedDescription)\n", stderr)
                return error as? CloudAuthError == .signInRequired ? 2 : 1
            }
        }

        if let i = args.firstIndex(of: "--pull") {
            guard i + 1 < args.count, !args[i + 1].hasPrefix("--") else {
                fputs("usage: ContextRecorder --pull <session-id> [--cloud <url>] [--into <library-folder>]\n", stderr)
                return 2
            }
            guard let config = cloudConfig() else { return 2 }
            do {
                var last = ""
                let root = value(args, "--into").map(path) ?? Session.root
                let folder = try await CloudPull.run(id: args[i + 1], config: config, into: root) { phase, f in
                    let line = String(format: "  %3.0f%%  %@", f * 100, phase)
                    if line != last { fputs(line + "\n", stderr); last = line }
                }
                print("Downloaded \(args[i + 1]) → \(folder.path)")
                return 0
            } catch {
                fputs("pull failed: \(error.localizedDescription)\n", stderr)
                return error as? CloudAuthError == .signInRequired ? 2 : 1
            }
        }

        if let i = args.firstIndex(of: "--push") {
            guard i + 1 < args.count, !args[i + 1].hasPrefix("--") else {
                fputs("usage: ContextRecorder --push <session-folder> [--cloud <url>]\n", stderr)
                return 2
            }
            let session = path(args[i + 1])
            guard let config = cloudConfig() else { return 2 }
            do {
                var last = ""
                let (record, report) = try await CloudPush.run(session: session, config: config) { phase, f in
                    let line = String(format: "  %3.0f%%  %@", f * 100, phase)
                    if line != last { fputs(line + "\n", stderr); last = line }
                }
                print("Pushed \(session.lastPathComponent) → \(record.url)")
                print("  uploaded \(report.uploaded.count) files (\(ByteCountFormatter.string(fromByteCount: report.uploadedBytes, countStyle: .file)))"
                      + (report.multipart.isEmpty ? "" : ", in parts: " + report.multipart.joined(separator: ", ")))
                print("  took " + CloudClient.Timing.summary(report.timings))
                print("  manifestSha256 \(record.manifestSha256)")
                print("  wrote \(CloudRecord.url(session).path)")
                return 0
            } catch CloudAuthError.signInRequired {
                fputs("push failed: Sign in from Cloud Settings in the app.\n", stderr)
                return 2
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
