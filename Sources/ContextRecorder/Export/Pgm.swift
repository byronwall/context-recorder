import Foundation

/// Runs the Product Grid CLI (`pgm`) against a local data folder.
///
/// Every call is `pgm <args> --local <dataDir> --json`: exports only ever write to the grid stored in a
/// project folder, never to a remote server. Arguments go straight to the process (no shell), so paths
/// and titles with spaces stay single arguments.
struct Pgm {
    let dataDir: URL

    struct Failure: LocalizedError {
        var message: String
        var notFound = false
        var errorDescription: String? { message }
    }

    /// The grid data for a project folder: `<folder>/pgm/data` (what `pgm viewer` uses by default), or
    /// the folder itself when it already is a data folder.
    static func dataDir(for folder: URL) -> URL {
        let fm = FileManager.default
        if fm.fileExists(atPath: folder.appendingPathComponent("projects").path) { return folder }
        return folder.appendingPathComponent("pgm/data")
    }

    /// Runs one command at a time (two pgm processes on one folder fight over its runtime lock), and
    /// retries while another runtime is still letting go of the folder.
    func run(_ args: [String]) async throws -> JSONValue {
        try await PgmQueue.shared.serial {
            var attempt = 0
            while true {
                do {
                    return try await runOnce(args)
                } catch let f as Failure where f.message.contains("Retry shortly") && attempt < 12 {
                    attempt += 1
                    try await Task.sleep(for: .milliseconds(350))
                }
            }
        }
    }

    private func runOnce(_ args: [String]) async throws -> JSONValue {
        let env = try await Self.environment()
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        let fullArgs = args + ["--local", dataDir.path, "--json"]
        precondition(fullArgs.contains("--local"), "pgm exports must stay local")

        return try await withCheckedThrowingContinuation { cont in
            let process = Process()
            process.executableURL = env.pgm
            process.arguments = fullArgs
            process.environment = env.variables
            process.currentDirectoryURL = dataDir
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            // Read both pipes as the process runs so a large reply can't block on a full buffer.
            let outBuf = Buffer(), errBuf = Buffer()
            let group = DispatchGroup()
            group.enter(); group.enter()
            DispatchQueue.global().async { outBuf.data = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            DispatchQueue.global().async { errBuf.data = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            process.terminationHandler = { p in
                group.wait()
                let outData = outBuf.data, errData = errBuf.data
                let stderr = String(decoding: errData, as: UTF8.self)
                guard p.terminationStatus == 0 else {
                    let message = Self.lastMeaningfulLine(stderr) ?? "pgm exited with status \(p.terminationStatus)"
                    cont.resume(throwing: Failure(message: message, notFound: message.localizedCaseInsensitiveContains("not found")))
                    return
                }
                do {
                    cont.resume(returning: try JSONDecoder().decode(JSONValue.self, from: outData))
                } catch {
                    cont.resume(throwing: Failure(message: "pgm returned unexpected output: \(String(decoding: outData.prefix(200), as: UTF8.self))"))
                }
            }
            do { try process.run() } catch { cont.resume(throwing: Failure(message: "Could not run pgm: \(error.localizedDescription)")) }
        }
    }

    /// Filled by one reader thread, read after the group finishes.
    private final class Buffer: @unchecked Sendable { var data = Data() }

    private static func lastMeaningfulLine(_ text: String) -> String? {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[viewer]") && !$0.hasPrefix("Using local viewer")
                && !$0.contains("pgm update") && !$0.hasPrefix("A fresh pgm update") }
            .last
    }

    // MARK: Finding pgm

    struct Environment { var pgm: URL; var variables: [String: String] }
    private static var cached: Environment?

    /// GUI apps get a minimal PATH, and pgm is usually installed through nvm. Ask a login shell once
    /// where pgm is and what PATH it runs with.
    static func environment() async throws -> Environment {
        if let cached { return cached }
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-lc", "command -v pgm; print -r -- $PATH"]
        let out = Pipe()
        probe.standardOutput = out
        probe.standardError = FileHandle.nullDevice
        try probe.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        probe.waitUntilExit()
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
        guard lines.count >= 2, lines[0].hasPrefix("/") else {
            throw Failure(message: "pgm isn't installed. Install it with `npm install -g @byronwallrus/product-grid-cli`.")
        }
        var vars = ProcessInfo.processInfo.environment
        vars["PATH"] = lines[1]
        let env = Environment(pgm: URL(fileURLWithPath: lines[0]), variables: vars)
        cached = env
        return env
    }

    // MARK: Commands

    struct Project: Identifiable, Hashable { var id: String; var name: String; var nodeCount: Int }
    struct Node: Identifiable, Hashable { var id: String; var title: String }

    func projects() async throws -> [Project] {
        let reply = try await run(["project", "list"])
        return (reply["projects"]?.arrayValue ?? []).compactMap { p in
            guard let id = p["id"]?.stringValue else { return nil }
            return Project(id: id, name: p["name"]?.stringValue ?? id, nodeCount: Int(p["nodeCount"]?.numberValue ?? 0))
        }
    }

    func createProject(name: String) async throws -> Project {
        let reply = try await run(["project", "create", name])
        guard let p = reply["project"], let id = p["id"]?.stringValue else { throw Failure(message: "pgm didn't return the new project") }
        return Project(id: id, name: p["name"]?.stringValue ?? name, nodeCount: 0)
    }

    func rootNodes(project: String) async throws -> [Node] {
        let reply = try await run(["node", "list", "--project", project, "--roots", "--preset", "compact"])
        return (reply["nodes"]?.arrayValue ?? []).compactMap { n in
            guard let id = n["id"]?.stringValue else { return nil }
            return Node(id: id, title: n["title"]?.stringValue ?? n["label"]?.stringValue ?? id)
        }
    }

    /// Whether a node still exists (it may have been deleted in the grid since the last export).
    func nodeExists(_ id: String, project: String) async throws -> Bool {
        do {
            _ = try await run(["node", "view", id, "--project", project, "--compact"])
            return true
        } catch let f as Failure where f.notFound {
            return false
        }
    }

    func createNode(project: String, title: String, parent: String?, contextFile: URL) async throws -> String {
        var args = ["node", "create", "--project", project, "--title", title, "--context-file", contextFile.path]
        if let parent { args += ["--parent", parent] }
        let reply = try await run(args)
        guard let id = reply["nodeId"]?.stringValue ?? reply["node"]?["id"]?.stringValue else {
            throw Failure(message: "pgm didn't return the new node")
        }
        return id
    }

    func setContext(_ id: String, project: String, file: URL) async throws {
        _ = try await run(["node", "context", "set", id, "--project", project, "--file", file.path])
    }

    func imageIDs(_ node: String, project: String) async throws -> [String] {
        let reply = try await run(["image", "list", node, "--project", project])
        return (reply["images"]?.arrayValue ?? []).compactMap { $0["id"]?.stringValue }
    }

    /// Adds images and returns the IDs of the ones just added.
    func addImages(_ node: String, project: String, files: [URL]) async throws -> [String] {
        guard !files.isEmpty else { return [] }
        let before = Set(try await imageIDs(node, project: project))
        let reply = try await run(["image", "add", node] + files.map(\.path) + ["--project", project])
        return (reply["images"]?.arrayValue ?? []).compactMap { $0["id"]?.stringValue }.filter { !before.contains($0) }
    }

    func removeImage(_ node: String, image: String, project: String) async throws {
        do {
            _ = try await run(["image", "remove", node, image, "--project", project])
        } catch let f as Failure where f.notFound {
            // Already gone from the grid: nothing to remove.
        }
    }
}

extension JSONValue {
    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }
}

/// Chains pgm calls so each starts after the previous one finished.
actor PgmQueue {
    static let shared = PgmQueue()
    private var tail: Task<Void, Never>?

    func serial<T: Sendable>(_ op: @escaping @Sendable () async throws -> T) async throws -> T {
        let previous = tail
        let task = Task { () async throws -> T in
            await previous?.value
            return try await op()
        }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }
}
