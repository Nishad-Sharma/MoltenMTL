import Foundation
import PackagePlugin

/// Build-tool plugin that compiles every `*.comp` GLSL shader in the consuming
/// package's `Shaders/` directory to SPIR-V with `glslc`, so `swift build`/`swift run`
/// produces the `.spv` automatically. Each command declares its input `.comp` and
/// output `.spv`, so SwiftPM only re-runs `glslc` when the shader source changes.
/// The compiled shaders land in the build's generated-resources directory and are
/// reachable at runtime via `Bundle.module`.
///
/// On Windows, the plugin path APIs surface POSIX-style `/C:/...` strings; `glslc`
/// rejects the leading slash before the drive letter, so `nativePath(_:)` strips it.
private func nativePath(_ path: Path) -> String {
    let s = path.string
    // Match a leading "/X:" drive-letter prefix and drop the leading slash.
    if s.count >= 3 {
        let chars = Array(s)
        if chars[0] == "/", chars[1].isLetter, chars[2] == ":" {
            return String(s.dropFirst())
        }
    }
    return s
}

@main
struct CompileShaders: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let vulkanInstall = ProcessInfo.processInfo.environment["VULKAN_INSTALL"] else {
            Diagnostics.error("VULKAN_INSTALL environment variable not set — cannot locate glslc.")
            return []
        }
        let glslc = Path(vulkanInstall).appending(subpath: "Bin/glslc.exe")

        let shaderDir = context.package.directory.appending(subpath: "Shaders")
        let shaders = try FileManager.default
            .contentsOfDirectory(atPath: shaderDir.string)
            .filter { $0.hasSuffix(".comp") }
            .sorted()

        return shaders.map { name in
            let input = shaderDir.appending(subpath: name)
            let spvName = (name as NSString).deletingPathExtension + ".spv"
            let output = context.pluginWorkDirectory.appending(subpath: spvName)

            return .buildCommand(
                displayName: "Compiling shader \(name)",
                executable: glslc,
                arguments: [
                    "--target-env=vulkan1.3",
                    nativePath(input),
                    "-o", nativePath(output),
                ],
                inputFiles: [input],
                outputFiles: [output]
            )
        }
    }
}
