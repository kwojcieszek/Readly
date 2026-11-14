// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadlyKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        // Domain
        .target(name: "ReadlyCore"),
        .target(name: "EPUBSupport", dependencies: ["ReadlyCore", "ZIPFoundation"]),
        .target(name: "PDFSupport", dependencies: ["ReadlyCore"]),
        .target(name: "TranslationCore"),
        .target(name: "Preferences", dependencies: ["TranslationCore"]),
        .target(name: "LibraryData", dependencies: ["ReadlyCore"]),
        .target(name: "Speech"),
        .target(name: "SystemTranslation", dependencies: ["TranslationCore"]),

        // UI
        .target(name: "DesignSystem"),
        .target(name: "LibraryFeature", dependencies: ["ReadlyCore", "LibraryData", "DesignSystem"]),
        .target(
            name: "ReaderFeature",
            dependencies: ["ReadlyCore", "LibraryData", "TranslationCore", "Preferences", "Speech", "DesignSystem"],
            resources: [.process("Resources")]
        ),
        .target(name: "SettingsFeature", dependencies: ["TranslationCore", "Preferences", "DesignSystem", "SystemTranslation"]),
        .target(
            name: "TranslatorFeature",
            dependencies: ["TranslationCore", "Preferences", "LibraryData", "Speech", "DesignSystem"]
        ),
        .target(
            name: "AppFeature",
            dependencies: [
                "ReadlyCore", "EPUBSupport", "PDFSupport", "TranslationCore", "Preferences", "LibraryData",
                "DesignSystem", "LibraryFeature", "ReaderFeature", "SettingsFeature", "TranslatorFeature",
                "SystemTranslation",
            ]
        ),

        // Tests
        .target(name: "EPUBFixtures", dependencies: ["ZIPFoundation"], path: "Tests/EPUBFixtures"),
        .testTarget(name: "SpeechTests", dependencies: ["Speech"]),
        .testTarget(name: "ReadlyCoreTests", dependencies: ["ReadlyCore"]),
        .testTarget(name: "EPUBSupportTests", dependencies: ["EPUBSupport", "EPUBFixtures"]),
        .testTarget(name: "PDFSupportTests", dependencies: ["PDFSupport", "ReadlyCore"]),
        .testTarget(name: "TranslationTests", dependencies: ["TranslationCore", "SystemTranslation"]),
        .testTarget(name: "LibraryDataTests", dependencies: ["LibraryData", "EPUBSupport", "PDFSupport", "EPUBFixtures"]),
        .testTarget(name: "ReaderFeatureTests", dependencies: ["ReaderFeature", "Preferences", "ReadlyCore", "TranslationCore"]),
    ],
    swiftLanguageModes: [.v6]
)
