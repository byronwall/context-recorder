import Foundation

/// A share link (docs/cloud-sessions.md §8): opens one cloud session in the viewer, read-only, without sign-in.
struct CloudShareLink: Codable, Equatable {
    var token: String
    var url: String
    var label: String?
    var createdAt: String
    var revokedAt: String?
    var views: Int?
}

extension CloudClient {
    /// A session's links, newest first, revoked ones included.
    func shares(_ id: String) async throws -> [CloudShareLink] {
        try await json("GET", "api/sessions/\(id)/shares", body: nil)
    }

    func createShare(_ id: String, label: String? = nil) async throws -> CloudShareLink {
        try await json("POST", "api/sessions/\(id)/shares", body: try JSONEncoder().encode(["label": label]))
    }

    /// The newest active link, or a new one. A label always makes a new link.
    func shareLink(_ id: String, label: String? = nil) async throws -> CloudShareLink {
        if label == nil, let active = try await shares(id).first(where: { $0.revokedAt == nil }) { return active }
        return try await createShare(id, label: label)
    }
}
