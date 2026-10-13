import AVFoundation
import Foundation
import Observation
import SwiftUI

/// One open session: its data, the player and the playhead every view shares.
@MainActor @Observable
final class SessionModel {
    let folder: URL
    private(set) var data: SessionData?
    private(set) var loadError: String?
    let player: AVPlayer

    /// Seconds into recording.mp4. Updated ~30×/s while playing; views that read it redraw then.
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    private(set) var videoDuration: Double?
    /// Pixel size of the recording, once the player knows it; the stage keeps this aspect ratio.
    private(set) var videoSize: CGSize?
    var rate: Float = 1 {
        didSet { if isPlaying { player.rate = rate } }
    }
    var selectedMark: Int?
    var tab: Tab = .marks
    var markFilter: MarkFilter = .all
    /// The open export sheet, if any.
    var export: ExportSheetModel?

    enum Tab: String, CaseIterable, Identifiable {
        case marks = "Marks", transcript = "Transcript", page = "Page Events", activity = "Activity"
        var id: String { rawValue }
    }
    enum MarkFilter: String, CaseIterable, Identifiable {
        case all = "All", mark = "Marks", screenshot = "Shots"
        var id: String { rawValue }
    }

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?

    init(folder: URL) {
        self.folder = folder
        let video = folder.appendingPathComponent("recording.mp4")
        player = AVPlayer(url: video)
        player.actionAtItemEnd = .pause
        reload()
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = t.seconds.isFinite ? t.seconds : 0
                self.isPlaying = self.player.rate != 0
            }
        }
        statusObserver = player.observe(\.currentItem?.status) { [weak self] player, _ in
            let seconds = player.currentItem?.duration.seconds
            let size = player.currentItem?.presentationSize
            DispatchQueue.main.async {
                if let seconds, seconds.isFinite, seconds > 0 { self?.videoDuration = seconds }
                if let size, size.width > 0, size.height > 0 { self?.videoSize = size }
            }
        }
    }

    func tearDown() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        statusObserver = nil
    }

    func reload() {
        let url = folder.appendingPathComponent("session.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            data = nil
            loadError = nil
            return
        }
        do {
            data = try JSONDecoder().decode(SessionData.self, from: Data(contentsOf: url))
            loadError = nil
            assignAppColors()
        } catch {
            loadError = "session.json could not be read: \(error.localizedDescription)"
        }
    }

    // MARK: Derived

    var marks: [SessionMark] { data?.marks ?? [] }
    var transcript: [Sentence] { data?.transcript ?? [] }
    var activity: [ActivityEntry] { data?.activity ?? [] }
    var pageEvents: [BrowserEntry] { data?.browser ?? [] }

    var duration: Double {
        if let videoDuration { return videoDuration }
        if let d = data?.duration, d > 0 { return d }
        return max(1, (marks.map(\.offsetSeconds).max() ?? 0) + 5)
    }

    var filteredMarks: [SessionMark] {
        switch markFilter {
        case .all: return marks
        case .mark: return marks.filter { !$0.isShot }
        case .screenshot: return marks.filter(\.isShot)
        }
    }

    /// Bundle ID for an app name, from the activity log.
    func bundleID(forApp name: String?) -> String? {
        activity.first { $0.context?.appName == name }?.context?.bundleID
    }

    var appCount: Int { Set(activity.compactMap { $0.context?.appName }).count }

    func url(_ relative: String?) -> URL? {
        guard let relative, !relative.isEmpty else { return nil }
        return folder.appendingPathComponent(relative)
    }

    func mark(_ index: Int?) -> SessionMark? { marks.first { $0.index == index } }

    func contextAt(_ t: Double) -> MarkContext? {
        var current = activity.first
        for a in activity { if a.offsetSeconds <= t { current = a } else { break } }
        return current?.context
    }

    func sentenceAt(_ t: Double) -> Sentence? {
        transcript.first { t >= $0.start - 0.2 && t <= $0.end + 0.6 }
    }

    // MARK: App colors (fixed muted palette, in order of first appearance)

    static let palette: [Color] = [
        Color(red: 0.36, green: 0.52, blue: 0.70), Color(red: 0.55, green: 0.45, blue: 0.68),
        Color(red: 0.38, green: 0.60, blue: 0.52), Color(red: 0.72, green: 0.52, blue: 0.38),
        Color(red: 0.62, green: 0.42, blue: 0.50), Color(red: 0.50, green: 0.56, blue: 0.38),
        Color(red: 0.42, green: 0.55, blue: 0.62), Color(red: 0.58, green: 0.52, blue: 0.46),
    ]
    @ObservationIgnored private var appColorIndex: [String: Int] = [:]

    private func assignAppColors() {
        appColorIndex = [:]
        for a in activity {
            let name = a.context?.appName ?? "?"
            if appColorIndex[name] == nil { appColorIndex[name] = appColorIndex.count }
        }
    }

    func color(forApp name: String?) -> Color {
        Self.palette[(appColorIndex[name ?? "?"] ?? 0) % Self.palette.count]
    }

    // MARK: Playback

    func seek(_ t: Double, play: Bool = false) {
        let clamped = min(max(0, t), duration)
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        if play { player.rate = rate; isPlaying = true }
    }

    func togglePlay() {
        if player.rate != 0 {
            player.pause()
            isPlaying = false
        } else {
            if currentTime >= duration - 0.05 { seek(0) }
            player.rate = rate
            isPlaying = true
        }
    }

    func skip(_ seconds: Double) { seek(currentTime + seconds) }

    func select(_ index: Int?, seek shouldSeek: Bool = true) {
        selectedMark = index
        if shouldSeek, let m = mark(index) {
            player.pause()
            isPlaying = false
            seek(m.offsetSeconds)
        }
    }

    /// J/K: the next or previous mark relative to the playhead.
    func step(_ direction: Int) {
        let sorted = marks.sorted { $0.offsetSeconds < $1.offsetSeconds }
        let t = currentTime
        let next = direction > 0
            ? sorted.first { $0.offsetSeconds > t + 0.3 }
            : sorted.last { $0.offsetSeconds < t - 0.3 }
        guard let next else { return }
        tab = .marks
        if markFilter == .mark && next.isShot || markFilter == .screenshot && !next.isShot { markFilter = .all }
        select(next.index)
    }

    func playFromBefore(_ m: SessionMark) {
        selectedMark = m.index
        seek(m.offsetSeconds - 5, play: true)
    }

    // MARK: Markdown

    var markdown: String {
        guard let data else { return "" }
        return MarkText.markdown(session: data, folder: folder.path)
    }

    func markdown(for m: SessionMark) -> String { MarkText.markdown(m, folder: folder.path) }
}
