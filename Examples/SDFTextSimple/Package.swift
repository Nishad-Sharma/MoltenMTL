// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SDFTextSimple",
    dependencies: [
        .package(path: "../.."),
        .package(path: "../Shared"),
    ],
    targets: [
        .executableTarget(
            name: "SDFTextSimple",
            dependencies: [
                .product(name: "MoltenMTL", package: "MoltenMTL"),
                .product(name: "ExampleSupport", package: "Shared"),
            ],
            path: "Sources/SDFTextSimple",
            resources: [
                .copy("Assets"),
            ],
            plugins: [
                .plugin(name: "CompileShaders", package: "MoltenMTL"),
            ]
        ),
    ]
)
