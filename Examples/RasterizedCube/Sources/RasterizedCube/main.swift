import Foundation
import MoltenMTL
import ExampleSupport

// MARK: - GPU layouts (raster-specific: MVP + per-mesh material/light)

struct VertexUniforms {
    var viewProj: float4x4
    var model: float4x4
}
struct FragUniforms {
    var diffuseColor: SIMD4<Float>
    var props: SIMD4<Float>             // x = useTexture (0/1), y = shininess, z = specStrength
    var lightPosIntensity: SIMD4<Float>
    var lightColorAmbient: SIMD4<Float>
    var eye: SIMD4<Float>
}

/// The vertex descriptor for the render pipeline. Must match `MeshBuffers`'s buffer layout:
/// position (buffer 0), normal (buffer 1), uv (buffer 2).
func makeMeshVertexDescriptor() -> MTLVertexDescriptor {
    let vd = MTLVertexDescriptor()
    vd.attributes[0].format = .float3; vd.attributes[0].bufferIndex = 0   // position
    vd.attributes[1].format = .float3; vd.attributes[1].bufferIndex = 1   // normal
    vd.attributes[2].format = .float2; vd.attributes[2].bufferIndex = 2   // uv
    vd.layouts[0].stride = MemoryLayout<MTLPackedFloat3>.stride  // 12
    vd.layouts[1].stride = MemoryLayout<SIMD4<Float>>.stride     // 16 (normals stored as vec4)
    vd.layouts[2].stride = MemoryLayout<SIMD2<Float>>.stride     // 8
    return vd
}

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
pipeDesc.vertexDescriptor = makeMeshVertexDescriptor()   // matches MeshBuffers's buffer layout
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

let viewProj = scene.camera.viewProjectionMatrix
let light = scene.light

let pass = MTLRenderPassDescriptor()
pass.colorAttachments[0].texture     = colorTexture
pass.colorAttachments[0].loadAction  = .clear
pass.colorAttachments[0].storeAction = .store
pass.colorAttachments[0].clearColor  = MTLClearColorMake(0, 0, 0, 1)   // black, matching RayTracedCube
pass.depthAttachment.texture     = depthTexture
pass.depthAttachment.loadAction  = .clear
pass.depthAttachment.storeAction = .dontCare
pass.depthAttachment.clearDepth  = 1.0

let cb  = queue.makeCommandBuffer()!
let enc = cb.makeRenderCommandEncoder(descriptor: pass)!
enc.setRenderPipelineState(pipeline)
enc.setDepthStencilState(depthState)
enc.setFragmentSamplerState(sampler, index: 0)

for (i, inst) in scene.instances.enumerated() {
    let material = inst.material

    var vu = VertexUniforms(viewProj: viewProj, model: inst.transform.modelMatrix)
    withUnsafeBytes(of: &vu) { enc.setVertexBytes($0.baseAddress!, length: $0.count, index: 3) }

    var fu = FragUniforms(
        diffuseColor: SIMD4(material.diffuseColor, 0),
        props: SIMD4(Float(material.textureIndex), material.shininess, material.specStrength, 0),
        lightPosIntensity: SIMD4(light.position, light.intensity),
        lightColorAmbient: SIMD4(light.color, light.ambient),
        eye: SIMD4(scene.camera.eye, 0))
    withUnsafeBytes(of: &fu) { enc.setFragmentBytes($0.baseAddress!, length: $0.count, index: 1) }

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

let readback = device.makeBuffer(length: imageSize * imageSize * 4, options: .storageModeShared)!
let blit = cb.makeBlitCommandEncoder()!
blit.copy(from: colorTexture, sourceSlice: 0, sourceLevel: 0,
          sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: imageSize, height: imageSize),
          to: readback, destinationOffset: 0,
          destinationBytesPerRow: imageSize * 4, destinationBytesPerImage: imageSize * imageSize * 4)
blit.endEncoding()
cb.commit()
cb.waitUntilCompleted()
print("Cube rendered ✓")

let ptr = readback.contents().bindMemory(to: UInt8.self, capacity: imageSize * imageSize * 4)
var rgb = [UInt8](repeating: 0, count: imageSize * imageSize * 3)
for i in 0..<(imageSize * imageSize) {
    rgb[i * 3 + 0] = ptr[i * 4 + 0]
    rgb[i * 3 + 1] = ptr[i * 4 + 1]
    rgb[i * 3 + 2] = ptr[i * 4 + 2]
}
let outURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output.ppm")
try writePPM(rgb, width: imageSize, height: imageSize, to: outURL)
print("Wrote \(outURL.path)")
