// swift-tools-version:6.2
import PackageDescription

// Shared support code for the examples: the render-agnostic scene model and small GPU
// helpers, so each example's main.swift highlights only its pipeline-specific setup.
let package = Package(
    name: "ExampleSupport",
    products: [
        .library(name: "ExampleSupport", targets: ["ExampleSupport"]),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/keyvariable/kvSIMD.swift.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "ExampleSupport",
            dependencies: [
                .product(name: "MoltenMTL", package: "MoltenMTL"),
                .product(name: "kvSIMD", package: "kvSIMD.swift")
            ]
        ),
    ]
)
