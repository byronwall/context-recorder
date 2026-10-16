import AVFoundation
import CanvasKit
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

    /// The cut list when the session has an edits.json; nil plays recording.mp4 as recorded.
    private(set) var edits: EditMap?
    /// What the player shows: recording.mp4, or the composition of the kept ranges. Previews read it too.
    private(set) var playbackAsset: AVAsset
    /// Set when a joined session's sources differ in size, so they share one frame.
    private(set) var playbackVideoComposition: AVVideoComposition?

    /// Seconds into the edited video (recording.mp4 when unedited). Updated ~30×/s while playing.
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
    /// The image viewer over the stage, if open.
    var viewer: ImageViewerModel?
    /// Bumped whenever annotations are saved; image views reload when it changes (an annotated copy is
    /// rewritten under the same name).
    var annotationRevision = 0

    // Review (marking up the recording afterwards)
    /// Dragging out a region on the video for a shot.
    var regionMode = false
    /// "Adding mark…" while a review change is being processed.
    var reviewStatus: String?
    var reviewError: String?
    /// The mark whose note field should take focus once it appears.
    var focusNoteFor: Int?
    /// Select this mark once re-processing brings it in.
    @ObservationIgnored var pendingSelect: Int?
    /// What a region drag on the video is for.
    var regionPurpose: RegionPurpose = .shot

    // Canvas (the recording laid out in space; see CanvasModel.swift)
    var stage: StageMode = .video
    /// canvas.json, when built and readable.
    var canvas: CanvasDocument?
    /// The recording no longer matches the canvas (re-recorded or replaced).
    var canvasStale = false
    /// canvas.json exists but an older version of the app built it; it can't be read, only rebuilt.
    var canvasOutdated = false
    /// 0…1 while a canvas is being built.
    var canvasProgress: Double?
    var canvasError: String?
    /// The moment under the pointer on the canvas; the now strip and transcript follow it.
    var previewTime: Double?
    /// Dragging out a region on the canvas to capture as a mark.
    var canvasSelecting = false
    @ObservationIgnored var canvasTask: Task<Void, Never>?
    @ObservationIgnored var canvasStamp: Date?

    enum StageMode: String, CaseIterable, Identifiable {
        case video = "Video", canvas = "Canvas"
        var id: String { rawValue }
    }
    enum RegionPurpose { case shot, canvasBox }
    /// Re-processing after annotations were saved; another save while it runs queues one more pass.
    @ObservationIgnored var annotationPass: Task<Void, Never>?
    @ObservationIgnored var annotationPassAgain = false

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
        let asset = AVURLAsset(url: folder.appendingPathComponent("recording.mp4"))
        playbackAsset = asset
        player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        player.actionAtItemEnd = .pause
        annotations = AnnotationsFile.load(folder)
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
        canvasTask?.cancel()
        viewer?.save()
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
            if let errors = data?.errors, !errors.isEmpty { reviewError = errors.joined(separator: "\n") }
            applyEdits()
            assignAppColors()
            reloadCanvas()
        } catch {
            loadError = "session.json could not be read: \(error.localizedDescription)"
        }
    }

    // MARK: Edits

    /// After a reload: play the cut list from edits.json, or the plain recording when there is none.
    private func applyEdits() {
        let edited = FileManager.default.fileExists(atPath: folder.appendingPathComponent("edits.json").path)
        let map = edited ? data.map { EditMap($0.segments) } : nil
        if map != edits { setEdits(map) }
    }

    /// The range picked on the timeline (Shift-drag, or I and O), in edited time.
    var selection: ClosedRange<Double>?
    /// Earlier and undone cut lists and annotation sets, for ⌘Z / ⇧⌘Z.
    var undoStack: [EditStep] = []
    var redoStack: [EditStep] = []

    // Annotations (drawing over the video)
    var annotations: [Annotation] = []
    /// Draw mode: the video pauses and RegionShot's tool keys apply.
    var drawMode = false
    var tool: AnnotationTool = .select
    var selectedAnnotation: UUID?
    /// The text annotation whose inline editor is open.
    var editingText: UUID?
    var annotationColor = AnnotationPalette.defaultStroke
    var highlightColor = AnnotationPalette.defaultHighlight

    @ObservationIgnored private var editGeneration = 0
    @ObservationIgnored private var seekCount = 0

    /// Swaps the player to a new cut list, keeping the playhead on the same moment of the recording (or
    /// the next kept moment, when that one was just cut).
    func setEdits(_ map: EditMap?) {
        let moment: (source: String, time: Double) = edits?.toSource(currentTime) ?? (".", currentTime)
        edits = map
        editGeneration += 1
        let generation = editGeneration
        let wasPlaying = isPlaying
        let seeksBefore = seekCount
        player.pause()
        Task {
            let asset: AVAsset
            var videoComposition: AVVideoComposition?
            if let map {
                do {
                    let playback = try await map.composition(in: folder)
                    asset = playback.asset
                    videoComposition = playback.videoComposition
                } catch {
                    reviewError = "The edited video couldn't be built: \(error.localizedDescription)"
                    return
                }
            } else {
                asset = AVURLAsset(url: folder.appendingPathComponent("recording.mp4"))
            }
            guard generation == editGeneration else { return }
            playbackAsset = asset
            playbackVideoComposition = videoComposition
            videoDuration = nil
            let item = AVPlayerItem(asset: asset)
            item.videoComposition = videoComposition
            player.replaceCurrentItem(with: item)
            // A seek made while the video was being built (selecting a mark) is already in edited time.
            let target = seekCount != seeksBefore ? currentTime
                : map.map { $0.nearestEdited(source: moment.source, moment.time) } ?? moment.time
            seek(target, play: wasPlaying)
        }
    }

    /// Where an edited time is in the raw recording: its folder, source name and time there.
    func sourcePoint(_ edited: Double) -> (folder: URL, source: String, time: Double) {
        let (source, time): (String, Double) = edits?.toSource(edited) ?? (".", edited)
        return (EditMap.folder(of: source, in: folder), source, time)
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

    /// In time order: marks added while reviewing get later numbers but belong where they happened.
    var filteredMarks: [SessionMark] {
        let sorted = marks.sorted { $0.offsetSeconds < $1.offsetSeconds }
        switch markFilter {
        case .all: return sorted
        case .mark: return sorted.filter { !$0.isShot }
        case .screenshot: return sorted.filter(\.isShot)
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

    /// Keep the latest started sentence lit briefly after it ends. A lead-in can select the next
    /// sentence when the clicked sentence is shorter than that lead-in.
    /// The playhead, or the moment under the pointer while hovering the canvas.
    var focusTime: Double { previewTime ?? currentTime }

    func sentenceAt(_ t: Double) -> Sentence? {
        guard let s = transcript.last(where: { $0.start <= t }), t <= s.end + 0.6 else { return nil }
        return s
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
        seekCount += 1
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
