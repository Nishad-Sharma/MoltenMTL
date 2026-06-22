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
    products: [
        .library(name: "MoltenMTL", targets: ["MoltenMTL"]),
        .plugin(name: "CompileShaders", targets: ["CompileShaders"]),
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
            name: "MoltenMTL",
            dependencies: ["CVulkan"],
            path: "Sources/MoltenMTL",
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-I\(vulkanSDK)/Include"])
            ]
        ),
        .testTarget(
            name: "MoltenMTLTests",
            dependencies: ["MoltenMTL"],
            path: "Tests/MoltenMTLTests",
            resources: [
                .copy("Resources/double.spv"),
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-I\(vulkanSDK)/Include"])
            ]
        ),
        .plugin(
            name: "CompileShaders",
            capability: .buildTool(),
            path: "Plugins/CompileShaders"
        ),
    ]
)
