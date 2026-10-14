import SwiftUI

/// Editing marks on the timeline: the selected range (Shift-drag, or I and O) with its Cut button, and a
/// scissors marker wherever a range was removed. Click a marker to see what was cut and restore it.
struct TimelineEditOverlay: View {
    var model: SessionModel
    var width: CGFloat
    var height: CGFloat
    @State private var openCut: EditMap.Cut?

    private func x(_ t: Double) -> CGFloat { CGFloat(t / max(model.duration, 0.001)) * width }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let range = model.selection { selectionBand(range) }
            ForEach(model.cuts) { cut in cutMarker(cut) }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    // MARK: Selection

    private func selectionBand(_ range: ClosedRange<Double>) -> some View {
        let left = x(range.lowerBound), right = x(range.upperBound)
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.16))
                .overlay(alignment: .leading) { Rectangle().fill(Color.accentColor).frame(width: 1.5) }
                .overlay(alignment: .trailing) { Rectangle().fill(Color.accentColor).frame(width: 1.5) }
                .frame(width: max(1.5, right - left), height: height)
                .offset(x: left)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            HStack(spacing: 6) {
                Text("\(Format.time(range.upperBound - range.lowerBound)) selected")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                Button {
                    model.cutSelection()
                } label: {
                    Label("Cut", systemImage: "scissors").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Remove the selected range (⌫)")
                Button { model.selection = nil } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear the selection (Esc)")
                    .accessibilityLabel("Clear selection")
            }
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.regularMaterial, in: .capsule)
            .fixedSize()
            .offset(x: min(max(0, (left + right) / 2 - 90), max(0, width - 180)), y: -34)
        }
    }

    // MARK: Cuts

    private func cutMarker(_ cut: EditMap.Cut) -> some View {
        let px = x(cut.editedAt)
        return ZStack(alignment: .topLeading) {
            Path { p in p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 0, y: height)) }
                .stroke(Color.orange.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 2, height: height)
                .offset(x: px - 1)
                .allowsHitTesting(false)

            Button { openCut = cut } label: {
                Image(systemName: "scissors")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.orange, in: .circle)
            }
            .buttonStyle(.plain)
            .offset(x: min(max(0, px - 8), width - 16), y: -16)
            .help("\(Format.time(cut.length)) cut here")
            .accessibilityLabel("Cut of \(Format.time(cut.length)) at \(Format.time(cut.editedAt))")
            .popover(isPresented: Binding(get: { openCut == cut }, set: { if !$0 { openCut = nil } }), arrowEdge: .top) {
                cutDetails(cut)
            }
        }
    }

    private func cutDetails(_ cut: EditMap.Cut) -> some View {
        let hidden = model.hiddenMarks(in: cut)
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(Format.time(cut.length)) removed").font(.headline)
            Text("\(Format.time(cut.start))–\(Format.time(cut.end)) of the recording")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
            if !hidden.isEmpty {
                Text(hidden.count == 1 ? "Restoring brings back 1 mark." : "Restoring brings back \(hidden.count) marks.")
                    .font(.system(size: 12))
            }
            Button {
                openCut = nil
                model.restore(cut)
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .frame(minWidth: 200, alignment: .leading)
    }
}
