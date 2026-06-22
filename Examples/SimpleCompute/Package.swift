// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SimpleCompute",
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "SimpleCompute",
            dependencies: [
                .product(name: "MoltenMTL", package: "MoltenMTL"),
            ],
            path: "Sources/SimpleCompute",
            plugins: [
                .plugin(name: "CompileShaders", package: "MoltenMTL"),
            ]
        ),
    ]
)
