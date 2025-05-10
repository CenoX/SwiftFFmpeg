// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftFFmpeg",
  products: [
    .library(
      name: "SwiftFFmpeg",
      targets: ["SwiftFFmpeg"]
    ),
    .library(
        name: "CFFmpeg",
        targets: ["CFFmpeg"]
    )
  ],
  targets: [
    .binaryTarget(name: "libavcodec",       path: "Scripts/output/xcframework/libavcodec.xcframework"),
    .binaryTarget(name: "libavformat",      path: "Scripts/output/xcframework/libavformat.xcframework"),
    .binaryTarget(name: "libavutil",        path: "Scripts/output/xcframework/libavutil.xcframework"),
    .binaryTarget(name: "libswscale",       path: "Scripts/output/xcframework/libswscale.xcframework"),
    .binaryTarget(name: "libswresample",    path: "Scripts/output/xcframework/libswresample.xcframework"),
    .binaryTarget(name: "libavfilter",      path: "Scripts/output/xcframework/libavfilter.xcframework"),

    .target(
      name: "CFFmpeg",
      dependencies: ["libavcodec", "libavformat", "libavutil", "libswscale", "libswresample", "libavfilter"],
      path: "Sources/CFFmpeg/",
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("./Scripts/output/iphoneos-arm64/include"),
        .headerSearchPath("./Scripts/output/macos-arm64/include"),
      ],
      linkerSettings: [
        .linkedFramework("CoreGraphics"),
        .linkedFramework("CoreAudio"),
        .linkedFramework("CoreImage"),
        .linkedFramework("VideoToolbox"),
        .linkedFramework("Foundation"),
        .linkedFramework("CoreMedia"),
        .linkedFramework("AudioToolbox"),
        .linkedFramework("AVFoundation"),
        .linkedLibrary("bz2"),
        .linkedLibrary("iconv"),
        .linkedLibrary("z"),
      ]
    ),
    
    .target(
      name: "SwiftFFmpeg",
      dependencies: ["CFFmpeg"],
      publicHeadersPath: "."
    ),
    .executableTarget(
      name: "Examples",
      dependencies: ["SwiftFFmpeg"]
    ),
    .testTarget(
      name: "Tests",
      dependencies: ["SwiftFFmpeg"]
    ),
  ]
)


