import AppKit
import SwiftUI

/// The real icon for an app, looked up by bundle ID (falls back to a generic app glyph).
struct AppIcon: View {
    var bundleID: String?
    var size: CGFloat = 16

    var body: some View {
        Image(nsImage: AppIcons.icon(bundleID))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

@MainActor
enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(_ bundleID: String?) -> NSImage {
        let key = bundleID ?? ""
        if let hit = cache[key] { return hit }
        let image: NSImage
        if let id = bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSWorkspace.shared.icon(for: .application)
        }
        cache[key] = image
        return image
    }
}

/// Numbered mark disc, the same on the timeline and in the list: amber for marks, green for shots.
struct MarkGlyph: View {
    var mark: SessionMark
    var size: CGFloat = 20
    var selected = false

    var body: some View {
        Text("\(mark.index)")
            .font(.system(size: size * 0.52, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill((mark.isShot ? Color.shot : Color.mark).gradient)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
            }
            .overlay {
                Circle().strokeBorder(.white.opacity(selected ? 0.95 : 0.35), lineWidth: selected ? 2 : 0.5)
            }
            .background {
                if selected { Circle().fill(Color.accentColor.opacity(0.35)).padding(-3) }
            }
            .accessibilityHidden(true)
    }
}

/// A rounded "inset grouped" block, like System Settings.
struct GroupBlock<Content: View>: View {
    var title: String?
    var symbol: String?
    var tint: Color = .secondary
    var trailing: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                HStack(spacing: 5) {
                    if let symbol { Image(systemName: symbol).foregroundStyle(tint) }
                    Text(title)
                    Spacer(minLength: 0)
                    if let trailing { Text(trailing).foregroundStyle(.tertiary) }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.opacity(0.7), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
        }
    }
}

/// A section of the mark inspector that folds away. Open or closed is remembered per section, so the
/// same sections stay open as you move from mark to mark.
struct InspectorSection<Content: View>: View {
    var title: String
    var symbol: String
    var tint: Color
    var trailing: String?
    @ViewBuilder var content: Content
    @AppStorage private var open: Bool

    init(_ id: String, title: String, symbol: String, tint: Color = .secondary, trailing: String? = nil,
         open defaultOpen: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.trailing = trailing
        self.content = content()
        _open = AppStorage(wrappedValue: defaultOpen, "inspector.section.\(id)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.snappy(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .frame(width: 10)
                    Image(systemName: symbol).foregroundStyle(tint).frame(width: 14)
                    Text(title).foregroundStyle(.primary)
                    if let trailing { Text(trailing).foregroundStyle(.tertiary).monospacedDigit() }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12, weight: .semibold))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(open ? "Expanded" : "Collapsed")
            if open {
                content.transition(.opacity)
            }
        }
    }
}

/// One row inside a GroupBlock, with a hairline between rows.
struct GroupRow<Content: View>: View {
    var divider = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            if divider { Divider().padding(.leading, 10) }
        }
    }
}

/// Small rounded icon button used in card headers and the floating transport.
struct IconButton: View {
    var symbol: String
    var help: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 24)
                .background(hovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

extension Color {
    static let mark = Color(red: 0.96, green: 0.62, blue: 0.10)     // amber
    static let shot = Color(red: 0.20, green: 0.68, blue: 0.42)     // green
    /// The gray macOS shows behind pages (Preview, Pages); the stage the video sits on.
    static let stage = Color(nsColor: .underPageBackgroundColor)
}
