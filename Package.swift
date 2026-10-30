// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PromptInjector",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PromptInjector", targets: ["PromptInjector"])],
    targets: [
        .systemLibrary(name: "CSQLite", path: "macOS/CSQLite"),
        .executableTarget(name: "PromptInjector", dependencies: ["CSQLite"], path: "macOS/PromptInjector", resources: [.copy("Resources/prompts.json"), .copy("Resources/Design")]),
        .testTarget(name: "PromptInjectorTests", dependencies: ["PromptInjector"], path: "macOS/PromptInjectorTests")
    ],
    swiftLanguageModes: [.v5]
)
