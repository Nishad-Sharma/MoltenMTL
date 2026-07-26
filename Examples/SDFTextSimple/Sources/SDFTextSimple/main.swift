import Foundation
import MoltenMTL
import ExampleSupport

let (device, queue) = makeDeviceAndQueue()

@MainActor func loadFont(_ name: String) -> FontAtlas {
    guard let jsonURL = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Assets"),
          let binURL  = Bundle.module.url(forResource: name, withExtension: "bin",  subdirectory: "Assets"),
          let jsonData = try? Data(contentsOf: jsonURL),
          let binData  = try? Data(contentsOf: binURL) else {
        fatalError("Failed to load Assets/\(name).json + Assets/\(name).bin")
    }
    do {
        return try FontAtlas(device: device, jsonData: jsonData, binData: binData)
    } catch {
        fatalError("\(error)")
    }
}

// sRGB target so the blend stage composites the anti-aliased glyph edges in
// linear light (see TextRasterizer.init).
let pixelFormat = MTLPixelFormat.rgba8Unorm_srgb

let rasterizer = try TextRasterizer(device: device, pixelFormat: pixelFormat)
rasterizer.fonts = [
    "inter":       loadFont("inter"),
    "sourceserif": loadFont("sourceserif"),
]

let imageWidth  = 832
let imageHeight = 704

let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: pixelFormat, width: imageWidth, height: imageHeight, mipmapped: false)
colorDesc.usage = .renderTarget
let colorTexture = device.makeTexture(descriptor: colorDesc)!

let clear = srgbToLinear(SIMD4(0.10, 0.11, 0.14, 1))

let text = "Hello MoltenMTL"
let sizes: [Float] = [16, 24, 40, 64, 96]

var elements: [TextElement] = []
var runningY: Float = 8
for font in ["inter", "sourceserif"] {
    for size in sizes {
        runningY += size * 1.25
        elements.append(TextElement(text: text, position: SIMD2(24, runningY),
                                     sizePx: size, font: font))
        runningY += 6
    }
    runningY += 20
}
rasterizer.elements = elements

let cb = queue.makeCommandBuffer()!

let clearPassDesc = MTLRenderPassDescriptor()
clearPassDesc.colorAttachments[0].texture     = colorTexture
clearPassDesc.colorAttachments[0].loadAction  = .clear
clearPassDesc.colorAttachments[0].storeAction = .store
clearPassDesc.colorAttachments[0].clearColor  = MTLClearColorMake(Double(clear.x), Double(clear.y), Double(clear.z), 1)
cb.makeRenderCommandEncoder(descriptor: clearPassDesc)!.endEncoding()

rasterizer.encodePass(commandBuffer: cb, target: colorTexture)

let outputPixelBuffer = device.makeBuffer(length: imageWidth * imageHeight * 4, options: .storageModeShared)!
let blitEnc = cb.makeBlitCommandEncoder()!
blitEnc.copy(from: colorTexture, sourceSlice: 0, sourceLevel: 0,
          sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: imageWidth, height: imageHeight),
          to: outputPixelBuffer, destinationOffset: 0,
          destinationBytesPerRow: imageWidth * 4, destinationBytesPerImage: imageWidth * imageHeight * 4)
blitEnc.endEncoding()
cb.commit()
cb.waitUntilCompleted()
print("Text rendered ✓ (\(elements.count) lines, 2 fonts × \(sizes.count) sizes, one atlas per font)")

let outputPixelPtr = outputPixelBuffer.contents().bindMemory(to: UInt8.self, capacity: imageWidth * imageHeight * 4)
var output = [UInt8](repeating: 0, count: imageWidth * imageHeight * 3)
for i in 0..<(imageWidth * imageHeight) {
    output[i * 3 + 0] = outputPixelPtr[i * 4 + 0]
    output[i * 3 + 1] = outputPixelPtr[i * 4 + 1]
    output[i * 3 + 2] = outputPixelPtr[i * 4 + 2]
}
let outputFilepath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output.ppm")
try writePPM(output, width: imageWidth, height: imageHeight, to: outputFilepath)
print("Wrote \(outputFilepath.path)")
