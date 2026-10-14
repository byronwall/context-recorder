// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ContextRecorder",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "canvas-tool", targets: ["CanvasTool"]),
    ],
    targets: [
        .executableTarget(
            name: "ContextRecorder",
            dependencies: ["CanvasKit"],
            path: "Sources/ContextRecorder",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("AVKit"),
                .linkedFramework("QuickLook"),
            ]
        ),
        // Video → canvas analysis: decoding with exact frame times, segmentation, canvas.json.
        .target(
            name: "CanvasKit",
            path: "Sources/CanvasKit",
            // Pixel loops: optimize even in debug builds, or a debug app takes minutes per canvas.
            swiftSettings: [.unsafeFlags(["-O"])],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreText"),
                .linkedFramework("Vision"),
            ]
        ),
        // Fixtures, analysis and contract checks from the command line (the fast local loop).
        .executableTarget(
            name: "CanvasTool",
            dependencies: ["CanvasKit"],
            path: "Sources/CanvasTool"
        ),
    ]
)
