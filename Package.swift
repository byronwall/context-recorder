// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ContextRecorder",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "ContextRecorder",
            dependencies: ["Annotation"],
            path: "Sources/ContextRecorder",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("AVKit"),
            ]
        ),
        // Image annotation shapes, hit-testing, rendering and undo. No AppKit, so it's unit-testable and
        // can be reused for annotations on video.
        .target(name: "Annotation", path: "Sources/Annotation"),
        .testTarget(name: "AnnotationTests", dependencies: ["Annotation"], path: "Tests/AnnotationTests"),
    ]
)
