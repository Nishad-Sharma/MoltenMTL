// swift-tools-version:6.2
import PackageDescription
import Foundation

let vulkanSDK: String = {
    guard let path = ProcessInfo.processInfo.environment["VULKAN_INSTALL"]
    else { fatalError("VULKAN_INSTALL environment variable not set.") }
    return path
}()                   

let package = Package(
    name: "MoltenMTL",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "MoltenMTL", targets: ["Metal"]),
    ],
    targets: [
        .target(
            name: "CVulkan",
            path: "Sources/CVulkan",
            publicHeadersPath: "include",
            cSettings: [
                .define("NOMINMAX"),
                .define("WIN32_LEAN_AND_MEAN"),
                .unsafeFlags(["-I\(vulkanSDK)/Include"]),
                .unsafeFlags(["-I\(vulkanSDK)/Source/SPIRV-Reflect"]),
            ],
            cxxSettings: [
                .define("NOMINMAX"),
                .define("WIN32_LEAN_AND_MEAN"),
                .define("VMA_IMPLEMENTATION"),
                .define("VMA_STATIC_VULKAN_FUNCTIONS",  to: "0"),
                .define("VMA_DYNAMIC_VULKAN_FUNCTIONS", to: "1"),
                .unsafeFlags(["-I\(vulkanSDK)/Include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L\(vulkanSDK)/Lib"]),
                .linkedLibrary("vulkan-1")
            ]
        ),
        .target(
            name: "Metal",
            dependencies: ["CVulkan"],
            path: "Sources/MoltenMTL",
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-I\(vulkanSDK)/Include"])
            ]
        ),
    ]
)
