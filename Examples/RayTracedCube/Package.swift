// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "RayTracedCube",
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "RayTracedCube",
            dependencies: [
                .product(name: "MoltenMTL", package: "MoltenMTL"),
            ],
            path: "Sources/RayTracedCube",
            plugins: [
                .plugin(name: "CompileShaders", package: "MoltenMTL"),
            ]
        ),
    ]
)
