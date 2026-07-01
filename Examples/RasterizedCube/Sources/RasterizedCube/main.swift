import Foundation
import MoltenMTL
import ExampleSupport

// MARK: - Setup

// cube.vert/cube.frag are compiled to SPIR-V by the CompileShaders build plugin and
// bundled as resources, so `swift run` produces them automatically.
guard let vertURL = Bundle.module.url(forResource: "cube.vert", withExtension: "spv"),
      let fragURL = Bundle.module.url(forResource: "cube.frag", withExtension: "spv") else {
    fatalError("Compiled shaders not found — the CompileShaders plugin did not run.")
}
let (device, queue) = makeDeviceAndQueue()
let scene = Scene.demo(device)      // shared scene (camera, light, mesh buffers)
let imageSize = 256

// MARK: - Pipeline + render targets

guard let vertLib = device.makeLibrary(path: vertURL.path),
      let fragLib = device.makeLibrary(path: fragURL.path),
      let vertFn  = vertLib.makeFunction(name: "main"),
      let fragFn  = fragLib.makeFunction(name: "main") else {
    fatalError("Failed to load shaders")
}

let pipeDesc = MTLRenderPipelineDescriptor()
pipeDesc.vertexFunction   = vertFn
pipeDesc.fragmentFunction = fragFn
let vertexDesc = MTLVertexDescriptor()
vertexDesc.attributes[0].format = .float3; vertexDesc.attributes[0].bufferIndex = 0   // position
vertexDesc.attributes[1].format = .float3; vertexDesc.attributes[1].bufferIndex = 1   // normal
vertexDesc.attributes[2].format = .float2; vertexDesc.attributes[2].bufferIndex = 2   // uv
vertexDesc.layouts[0].stride = MemoryLayout<MTLPackedFloat3>.stride            // 12
vertexDesc.layouts[1].stride = MemoryLayout<SIMD4<Float>>.stride              // 16 (normals stored as vec4)
vertexDesc.layouts[2].stride = MemoryLayout<SIMD2<Float>>.stride              // 8
pipeDesc.vertexDescriptor = vertexDesc
pipeDesc.colorAttachments[0].pixelFormat = .rgba8Unorm
pipeDesc.depthAttachmentPixelFormat      = .depth32Float
let pipeline = try device.makeRenderPipelineState(descriptor: pipeDesc)

let depthDesc = MTLDepthStencilDescriptor()
depthDesc.depthCompareFunction = .lessEqual
depthDesc.isDepthWriteEnabled  = true
let depthState = device.makeDepthStencilState(descriptor: depthDesc)

let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .rgba8Unorm, width: imageSize, height: imageSize, mipmapped: false)
colorDesc.usage = .renderTarget
let colorTexture = device.makeTexture(descriptor: colorDesc)!

let depthTexDesc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .depth32Float, width: imageSize, height: imageSize, mipmapped: false)
depthTexDesc.usage = .renderTarget
let depthTexture = device.makeTexture(descriptor: depthTexDesc)!

// MARK: - Per-mesh textures + sampler

// One sampled texture per instance (a 1×1 white fallback for instances with no texture —
// the fragment shader ignores it via the textureIndex flag, but a sampler2D must be bound).
let fallbackTexture = uploadTexture(device, .solid(SIMD3<Float>(1, 1, 1), size: 1), usage: .shaderRead)
let instanceTextures = scene.instances.map { inst in
    inst.material.textureIndex >= 0
        ? uploadTexture(device, scene.textures[Int(inst.material.textureIndex)], usage: .shaderRead)
        : fallbackTexture
}
let samplerDesc = MTLSamplerDescriptor()
samplerDesc.minFilter = .linear
samplerDesc.magFilter = .linear
let sampler = device.makeSamplerState(descriptor: samplerDesc)!

// MARK: - Draw

let renderPassDesc = MTLRenderPassDescriptor()
renderPassDesc.colorAttachments[0].texture     = colorTexture
renderPassDesc.colorAttachments[0].loadAction  = .clear
renderPassDesc.colorAttachments[0].storeAction = .store
renderPassDesc.colorAttachments[0].clearColor  = MTLClearColorMake(0, 0, 0, 1)   // black, matching RayTracedCube
renderPassDesc.depthAttachment.texture     = depthTexture
renderPassDesc.depthAttachment.loadAction  = .clear
renderPassDesc.depthAttachment.storeAction = .dontCare
renderPassDesc.depthAttachment.clearDepth  = 1.0

let cb  = queue.makeCommandBuffer()!
let enc = cb.makeRenderCommandEncoder(descriptor: renderPassDesc)!
enc.setRenderPipelineState(pipeline)
enc.setDepthStencilState(depthState)
enc.setFragmentSamplerState(sampler, index: 0)

for (i, inst) in scene.instances.enumerated() {
    withUnsafeBytes(of: scene.camera) { enc.setVertexBytes($0.baseAddress!, length: $0.count, index: 3) }
    withUnsafeBytes(of: inst)         { enc.setVertexBytes($0.baseAddress!, length: $0.count, index: 4) }
    withUnsafeBytes(of: inst.material)   { enc.setFragmentBytes($0.baseAddress!, length: $0.count, index: 1) }
    withUnsafeBytes(of: scene.light)     { enc.setFragmentBytes($0.baseAddress!, length: $0.count, index: 2) }
    withUnsafeBytes(of: scene.camera)    { enc.setFragmentBytes($0.baseAddress!, length: $0.count, index: 3) }

    enc.setFragmentTexture(instanceTextures[i], index: 0)

    let g = scene.meshBuffers[inst.meshIndex]
    enc.setVertexBuffer(g.positions, offset: 0, index: 0)
    enc.setVertexBuffer(g.normals,   offset: 0, index: 1)
    enc.setVertexBuffer(g.uvs,       offset: 0, index: 2)
    enc.drawIndexedPrimitives(type: .triangle, indexCount: g.indexCount,
                              indexType: .uint32, indexBuffer: g.indices, indexBufferOffset: 0)
}
enc.endEncoding()

// MARK: - Readback → PPM

let outputPixelBuffer = device.makeBuffer(length: imageSize * imageSize * 4, options: .storageModeShared)!
let blitEnc = cb.makeBlitCommandEncoder()!
blitEnc.copy(from: colorTexture, sourceSlice: 0, sourceLevel: 0,
          sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: imageSize, height: imageSize),
          to: outputPixelBuffer, destinationOffset: 0,
          destinationBytesPerRow: imageSize * 4, destinationBytesPerImage: imageSize * imageSize * 4)
blitEnc.endEncoding()
cb.commit()
cb.waitUntilCompleted()
print("Cube rendered ✓")

let outputPixelPtr = outputPixelBuffer.contents().bindMemory(to: UInt8.self, capacity: imageSize * imageSize * 4)
var output = [UInt8](repeating: 0, count: imageSize * imageSize * 3)
for i in 0..<(imageSize * imageSize) {
    output[i * 3 + 0] = outputPixelPtr[i * 4 + 0]
    output[i * 3 + 1] = outputPixelPtr[i * 4 + 1]
    output[i * 3 + 2] = outputPixelPtr[i * 4 + 2]
}
let outputFilepath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output.ppm")
try writePPM(output, width: imageSize, height: imageSize, to: outputFilepath)
print("Wrote \(outputFilepath.path)")
