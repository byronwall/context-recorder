import Foundation
import Network

/// Local WebSocket server the Chrome extension connects to (ws://127.0.0.1:47823).
///
/// Extension → app:  {"type":"event", "event":{...}}            streamed page events (clicks, nav, errors, failed requests)
///                   {"type":"snapshot-result", "id", "data"}   reply to a snapshot request
/// App → extension:  {"type":"snapshot", "id"}                  "what's under the mouse right now?"
///
/// Only connections whose Origin is a chrome-extension:// URL are accepted, so web pages can't connect.
final class BrowserBridge {
    static let port: UInt16 = 47823

    var onEvent: ((JSONValue) -> Void)?          // main queue
    var onConnectionsChanged: ((Int) -> Void)?   // main queue

    private let queue = DispatchQueue(label: "context-recorder.bridge")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var pending: [String: (JSONValue?) -> Void] = [:]

    func start() {
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        ws.maximumMessageSize = 4 * 1024 * 1024
        ws.setClientRequestHandler(queue) { _, headers in
            let origin = headers.first { $0.name.lowercased() == "origin" }?.value ?? ""
            let allowed = origin.isEmpty || origin.hasPrefix("chrome-extension://")
            if !allowed { NSLog("ContextRecorder: rejected browser bridge connection from origin \(origin)") }
            return NWProtocolWebSocket.Response(status: allowed ? .accept : .reject, subprotocol: nil, additionalHeaders: nil)
        }
        let params = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: Self.port)!)
        params.allowLocalEndpointReuse = true
        do {
            let listener = try NWListener(using: params)
            listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state { NSLog("ContextRecorder: browser bridge failed: \(error)") }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            NSLog("ContextRecorder: could not start browser bridge: \(error)")
        }
    }

    /// Ask the extension for a page snapshot. Completes on main with nil if no extension answers in time.
    func requestSnapshot(timeout: TimeInterval = 0.6, completion: @escaping (JSONValue?) -> Void) {
        queue.async {
            guard !self.connections.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let id = UUID().uuidString
            self.pending[id] = { value in DispatchQueue.main.async { completion(value) } }
            for conn in self.connections.values { self.send(["type": "snapshot", "id": id], on: conn) }
            self.queue.asyncAfter(deadline: .now() + timeout) {
                self.pending.removeValue(forKey: id)?(nil)
            }
        }
    }

    // MARK: Connections

    private func accept(_ conn: NWConnection) {
        let key = ObjectIdentifier(conn)
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.connections[key] = conn
                self.notifyCount()
            case .failed, .cancelled:
                if self.connections.removeValue(forKey: key) != nil { self.notifyCount() }
            default:
                break
            }
        }
        conn.start(queue: queue)
        receive(on: conn)
    }

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, !data.isEmpty { self.handle(data) }
            if error == nil { self.receive(on: conn) } else { conn.cancel() }
        }
    }

    private func handle(_ data: Data) {
        guard let message = try? JSONDecoder().decode(JSONValue.self, from: data) else { return }
        switch message["type"]?.stringValue {
        case "event":
            if let event = message["event"] { DispatchQueue.main.async { self.onEvent?(event) } }
        case "snapshot-result":
            if let id = message["id"]?.stringValue, let callback = pending.removeValue(forKey: id) {
                callback(message["data"])
            }
        default:
            break // hello / ping
        }
    }

    private func send(_ object: [String: Any], on conn: NWConnection) {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [meta])
        conn.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func notifyCount() {
        let count = connections.count
        DispatchQueue.main.async { self.onConnectionsChanged?(count) }
    }
}
