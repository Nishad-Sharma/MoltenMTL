// swift-tools-version:6.2
import PackageDescription
import Foundation

let vulkanSDK = ProcessInfo.processInfo.environment["VULKAN_INSTALL"]
    ?? ProcessInfo.processInfo.environment["VULKAN_SDK"]
    ?? ""

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
                .define("SPIRV_REFLECT_USE_SYSTEM_SPIRV_H"),
            ],
            cxxSettings: [
                .define("NOMINMAX"),
                .define("WIN32_LEAN_AND_MEAN"),
                .define("SPIRV_REFLECT_USE_SYSTEM_SPIRV_H"),
                .define("VMA_IMPLEMENTATION"),
                .define("VMA_STATIC_VULKAN_FUNCTIONS",  to: "0"),
                .define("VMA_DYNAMIC_VULKAN_FUNCTIONS", to: "1"),
            ],
            linkerSettings: [
                .unsafeFlags(["-L\(vulkanSDK)/Lib"]),
                .linkedLibrary("vulkan-1")
            ]
        ),
        .target(
            name: "Metal",
            dependencies: ["CVulkan"],
            path: "Sources/MoltenMTL"
        ),
    ]
)
