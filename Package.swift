// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Terra",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TerraPreview", targets: ["TerraPreview"])],
    targets: [
        .target(name: "TerraAstronomy", path: "Sources/AstronomyC",exclude: ["LICENSE"],publicHeadersPath: "include"),
        .target(name: "TerraCore", dependencies: ["TerraAstronomy"],path: "Sources/Core"),
        .target(name: "TerraScene", dependencies: ["TerraCore"], path: ".",
                exclude: ["Sources/AstronomyC", "Sources/Core", "Sources/Preview", "Sources/Screensaver", "Tests", "Scripts", "Docs", "README.md", "Build", ".build", "Package.swift", "Terra.xcodeproj"],
                sources: ["Sources/Rendering", "Sources/UI"], resources: [.copy("Resources")]),
        .executableTarget(name: "TerraPreview", dependencies: ["TerraCore", "TerraScene"], path: "Sources/Preview"),
        .testTarget(name: "TerraCoreTests", dependencies: ["TerraCore"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
