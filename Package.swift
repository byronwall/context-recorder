// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ContextRecorder",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "ContextRecorder",
            path: "Sources/ContextRecorder",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("AVKit"),
            ]
        )
    ]
)
