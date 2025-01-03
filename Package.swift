// swift-tools-version: 6.0

import PackageDescription

// MARK: - Package Configuration

let package = Package(
    name: "ChessKitEngine",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
        .macOS(.v13),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "ChessKitEngine",
            targets: ["ChessKitEngine"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", .upToNextMajor(from: "1.0.3"))
    ],
    targets: [
        .target(
            name: "ChessKitEngine",
            dependencies: [
                "ChessKitEngineCore",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]
        ),
        .target(
            name: "ChessKitEngineCore",
            cxxSettings: [
                //lc0
                .headerSearchPath("Engines/lc0/"),
                .headerSearchPath("Engines/lc0/src"),
                .headerSearchPath("Engines/lc0/subprojects/eigen-3.4.0"),
                .define("NNUE_EMBEDDING_OFF"),
                .define("NO_PEXT"),
                //arasan
                .headerSearchPath("Engines/Arasan/src"),
                .headerSearchPath("Engines/Arasan/src/nnue"),
                .define("ARASAN_VERSION=v25.0"),
                .define("_64BIT"),
                .define("USE_INTRINSICS"),
                .define("USE_ASM"),
                .define("SYZYGY_TBS"),
                .define("SMP"),
                .define("SMP_STATS"),

            ],
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        .testTarget(
            name: "ChessKitEngineTests",
            dependencies: ["ChessKitEngine"],
            resources: [
                .copy("EngineTests/Resources/192x15_network"),
                .copy("EngineTests/Resources/book.bin")
            ]
        )
    ],
    cxxLanguageStandard: .gnucxx17
)

// MARK: - ChessKitEngineCore excludes

package.targets.first { $0.name == "ChessKitEngineCore" }?.exclude = [
    // lc0
    "Engines/lc0/build",
    "Engines/lc0/cross-files",
    "Engines/lc0/dist",
    "Engines/lc0/libs",
    "Engines/lc0/scripts",
    "Engines/lc0/subprojects/eigen-3.4.0/bench",
    "Engines/lc0/subprojects/eigen-3.4.0/blas",
    "Engines/lc0/subprojects/eigen-3.4.0/ci",
    "Engines/lc0/subprojects/eigen-3.4.0/cmake",
    "Engines/lc0/subprojects/eigen-3.4.0/debug",
    "Engines/lc0/subprojects/eigen-3.4.0/demos",
    "Engines/lc0/subprojects/eigen-3.4.0/doc",
    "Engines/lc0/subprojects/eigen-3.4.0/failtest",
    "Engines/lc0/subprojects/eigen-3.4.0/lapack",
    "Engines/lc0/subprojects/eigen-3.4.0/scripts",
    "Engines/lc0/subprojects/eigen-3.4.0/test",
    "Engines/lc0/subprojects/eigen-3.4.0/unsupported",
    "Engines/lc0/third_party",
    "Engines/lc0/src/utils/filesystem.win32.cc",
    "Engines/lc0/src/chess/board_test.cc",
    "Engines/lc0/src/chess/position_test.cc",
    "Engines/lc0/src/neural/encoder_test.cc",
    "Engines/lc0/src/syzygy/syzygy_test.cc",
    "Engines/lc0/src/utils/hashcat_test.cc",
    "Engines/lc0/src/utils/optionsparser_test.cc",
    "Engines/lc0/src/benchmark/",
    "Engines/lc0/src/lc0ctl/",
    "Engines/lc0/src/python/",
    "Engines/lc0/src/selfplay/",
    "Engines/lc0/src/trainingdata/",
    "Engines/lc0/src/neural/cuda/",
    "Engines/lc0/src/neural/dx/",
    "Engines/lc0/src/neural/metal/",
    "Engines/lc0/src/neural/network_tf_cc.cc",
    "Engines/lc0/src/neural/onednn/",
    "Engines/lc0/src/neural/onnx/",
    "Engines/lc0/src/neural/opencl/",
    "Engines/lc0/src/neural/xla/",
    "Engines/lc0/src/rescorer/",
    "Engines/lc0/src/rescorer_main.cc",
    //Arasan
    "Engines/Arasan/src/unit.cpp",
    "Engines/Arasan/src/tune.cpp",
    "Engines/Arasan/src/topo.cpp",
    "Engines/Arasan/src/util",
    "Engines/Arasan/src/nnue",
    "Engines/Arasan/src/nnue/test",
    "Engines/Arasan/src/bitbase.cpp",
]
