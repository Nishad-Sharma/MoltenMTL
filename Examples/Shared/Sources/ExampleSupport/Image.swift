import Foundation
import MoltenMTL

// MARK: - CPU image data

/// CPU-side RGBA8 image, row-major and tightly packed. Uploaded to an `MTLTexture`.
public struct TextureData {
    public var width: Int
    public var height: Int
    public var pixels: [UInt8]   // width * height * 4 bytes

    public init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width; self.height = height; self.pixels = pixels
    }

    /// A plain single-colour texture, generated procedurally so the examples need no
    /// asset files. Still a real sampled texture — every texel is `color`.
    public static func solid(_ color: SIMD3<Float>, size: Int = 16) -> TextureData {
        let r = UInt8(max(0, min(255, Int(color.x * 255))))
        let g = UInt8(max(0, min(255, Int(color.y * 255))))
        let b = UInt8(max(0, min(255, Int(color.z * 255))))
        var px = [UInt8](repeating: 0, count: size * size * 4)
        for i in 0..<(size * size) {
            px[i * 4 + 0] = r
            px[i * 4 + 1] = g
            px[i * 4 + 2] = b
            px[i * 4 + 3] = 255
        }
        return TextureData(width: size, height: size, pixels: px)
    }
}

// MARK: - GPU upload

/// Uploads RGBA8 pixel data into a 2-D texture. The ray tracer passes
/// `[.shaderRead, .shaderWrite]` (storage image, read via `imageLoad`); the rasterizer
/// passes `.shaderRead` (a sampled texture).
public func uploadTexture(_ device: MTLDevice, _ data: TextureData, usage: MTLTextureUsage) -> MTLTexture {
    let desc = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm, width: data.width, height: data.height, mipmapped: false)
    desc.usage = usage
    let tex = device.makeTexture(descriptor: desc)!
    data.pixels.withUnsafeBytes {
        tex.replace(region: .make2D(width: data.width, height: data.height),
                    mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: data.width * 4)
    }
    return tex
}

// MARK: - File output

/// Writes tightly-packed RGB bytes (`width * height * 3`) as a binary PPM (P6) file.
public func writePPM(_ rgb: [UInt8], width: Int, height: Int, to url: URL) throws {
    var ppm = Data()
    ppm.append(contentsOf: "P6\n\(width) \(height)\n255\n".utf8)
    ppm.append(contentsOf: rgb)
    try ppm.write(to: url)
}
