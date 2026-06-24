// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "RasterizedCube",
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "RasterizedCube",
            dependencies: [
                .product(name: "MoltenMTL", package: "MoltenMTL"),
            ],
            path: "Sources/RasterizedCube",
            plugins: [
                .plugin(name: "CompileShaders", package: "MoltenMTL"),
            ]
        ),
    ]
)
