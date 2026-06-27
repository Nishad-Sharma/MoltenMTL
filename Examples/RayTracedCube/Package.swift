// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "RayTracedCube",
    dependencies: [
        .package(path: "../.."),
        .package(path: "../Shared"),
    ],
    targets: [
        .executableTarget(
            name: "RayTracedCube",
            dependencies: [
                .product(name: "MoltenMTL", package: "MoltenMTL"),
                .product(name: "ExampleSupport", package: "Shared"),
            ],
            path: "Sources/RayTracedCube",
            plugins: [
                .plugin(name: "CompileShaders", package: "MoltenMTL"),
            ]
        ),
    ]
)
