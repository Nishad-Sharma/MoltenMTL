import Foundation
import MoltenMTL

// cube.vert/cube.frag are compiled to SPIR-V by the CompileShaders build plugin and
// bundled as resources, so `swift run` produces them automatically.
guard let vertURL = Bundle.module.url(forResource: "cube.vert", withExtension: "spv"),
      let fragURL = Bundle.module.url(forResource: "cube.frag", withExtension: "spv") else {
    fatalError("Compiled shaders not found — the CompileShaders plugin did not run.")
}

guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("No Vulkan-capable GPU found")
}
let queue = device.makeCommandQueue()!

// The scene is shared with RayTracedCube (same camera, light, geometry, materials, texture).
let scene = Scene.demo()
let imageSize = 256

// MARK: - GPU uniform layouts (mirror the shader's uniform blocks; vec4/mat4 only)

struct VertexUniforms {
    var viewProj: float4x4
    var model: float4x4
}
struct FragUniforms {
    var albedo: SIMD4<Float>
    var props: SIMD4<Float>             // x = mode, y = shininess, z = specStrength
    var lightPosIntensity: SIMD4<Float>
    var lightColorAmbient: SIMD4<Float>
    var eye: SIMD4<Float>
}

// MARK: - Shaders + pipeline

guard let vertLib = device.makeLibrary(path: vertURL.path),
      let fragLib = device.makeLibrary(path: fragURL.path),
      let vertFn  = vertLib.makeFunction(name: "main"),
      let fragFn  = fragLib.makeFunction(name: "main") else {
    fatalError("Failed to load shaders")
}

// Vertex layout: position (buffer 0), normal (buffer 1), uv (buffer 2).
let vertexDescriptor = MTLVertexDescriptor()
vertexDescriptor.attributes[0].format = .float3
vertexDescriptor.attributes[0].offset = 0
vertexDescriptor.attributes[0].bufferIndex = 0
vertexDescriptor.attributes[1].format = .float3
vertexDescriptor.attributes[1].offset = 0
vertexDescriptor.attributes[1].bufferIndex = 1
vertexDescriptor.attributes[2].format = .float2
vertexDescriptor.attributes[2].offset = 0
vertexDescriptor.attributes[2].bufferIndex = 2
vertexDescriptor.layouts[0].stride = MemoryLayout<MTLPackedFloat3>.stride  // 12
vertexDescriptor.layouts[1].stride = MemoryLayout<SIMD4<Float>>.stride     // 16 (normals stored as vec4)
vertexDescriptor.layouts[2].stride = MemoryLayout<SIMD2<Float>>.stride     // 8

let pipeDesc = MTLRenderPipelineDescriptor()
pipeDesc.vertexFunction   = vertFn
pipeDesc.fragmentFunction = fragFn
pipeDesc.vertexDescriptor = vertexDescriptor
pipeDesc.colorAttachments[0].pixelFormat = .rgba8Unorm
pipeDesc.depthAttachmentPixelFormat      = .depth32Float
let pipeline = try device.makeRenderPipelineState(descriptor: pipeDesc)

let depthDesc = MTLDepthStencilDescriptor()
depthDesc.depthCompareFunction = .lessEqual
depthDesc.isDepthWriteEnabled  = true
let depthState = device.makeDepthStencilState(descriptor: depthDesc)

// MARK: - Render targets

let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .rgba8Unorm, width: imageSize, height: imageSize, mipmapped: false)
colorDesc.usage = .renderTarget
let colorTexture = device.makeTexture(descriptor: colorDesc)!

let depthTexDesc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .depth32Float, width: imageSize, height: imageSize, mipmapped: false)
depthTexDesc.usage = .renderTarget
let depthTexture = device.makeTexture(descriptor: depthTexDesc)!

// MARK: - Cube texture + sampler (real filtered sampling, unlike the ray example)

let texData = scene.texture
let texDesc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .rgba8Unorm, width: texData.width, height: texData.height, mipmapped: false)
texDesc.usage = .shaderRead
let cubeTexture = device.makeTexture(descriptor: texDesc)!
texData.pixels.withUnsafeBytes {
    cubeTexture.replace(
        region: .make2D(width: texData.width, height: texData.height),
        mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: texData.width * 4)
}
let samplerDesc = MTLSamplerDescriptor()
samplerDesc.minFilter = .linear
samplerDesc.magFilter = .linear
let sampler = device.makeSamplerState(descriptor: samplerDesc)!

// MARK: - Per-object vertex/index buffers

struct GPUMesh {
    let positions: MTLBuffer
    let normals: MTLBuffer
    let uvs: MTLBuffer
    let indices: MTLBuffer
    let indexCount: Int
}

let gpuMeshes: [GPUMesh] = scene.objects.map { obj in
    let m = obj.mesh
    return GPUMesh(
        positions: device.makeBuffer(bytes: m.vertices,
                                     length: m.vertices.count * MemoryLayout<MTLPackedFloat3>.stride,
                                     options: .storageModeShared)!,
        normals:   device.makeBuffer(bytes: m.normals,
                                     length: m.normals.count * MemoryLayout<SIMD4<Float>>.stride,
                                     options: .storageModeShared)!,
        uvs:       device.makeBuffer(bytes: m.uvs,
                                     length: m.uvs.count * MemoryLayout<SIMD2<Float>>.stride,
                                     options: .storageModeShared)!,
        indices:   device.makeBuffer(bytes: m.indices,
                                     length: m.indices.count * MemoryLayout<UInt32>.stride,
                                     options: .storageModeShared)!,
        indexCount: m.indices.count)
}

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
enc.setFragmentTexture(cubeTexture, index: 0)        // set 1, binding 0
enc.setFragmentSamplerState(sampler, index: 0)

for (i, obj) in scene.objects.enumerated() {
    let material = scene.materials[obj.materialIndex]

    var vu = VertexUniforms(viewProj: viewProj, model: obj.transform.modelMatrix)
    withUnsafeBytes(of: &vu) {                         // set 0, binding 3
        enc.setVertexBytes($0.baseAddress!, length: $0.count, index: 3)
    }

    var fu = FragUniforms(
        albedo: material.albedo.simd4,
        props: SIMD4(material.mode.rawValue, material.shininess, material.specStrength, 0),
        lightPosIntensity: SIMD4(light.position.x, light.position.y, light.position.z, light.intensity),
        lightColorAmbient: SIMD4(light.color.x, light.color.y, light.color.z, light.ambient),
        eye: scene.camera.eye.simd4)
    withUnsafeBytes(of: &fu) {                         // set 1, binding 1
        enc.setFragmentBytes($0.baseAddress!, length: $0.count, index: 1)
    }

    let g = gpuMeshes[i]
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
          destinationBytesPerRow: imageSize * 4,
          destinationBytesPerImage: imageSize * imageSize * 4)
blit.endEncoding()
cb.commit()
cb.waitUntilCompleted()
print("Cube rendered ✓")

let ptr = readback.contents().bindMemory(to: UInt8.self, capacity: imageSize * imageSize * 4)
var ppm = Data()
ppm.append(contentsOf: "P6\n\(imageSize) \(imageSize)\n255\n".utf8)
for i in 0..<(imageSize * imageSize) {
    let base = i * 4
    ppm.append(ptr[base])
    ppm.append(ptr[base + 1])
    ppm.append(ptr[base + 2])
}

let outURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("output.ppm")
try ppm.write(to: outURL)
print("Wrote \(outURL.path)")
print("Open with: any image viewer, VS Code (PPM viewer extension), or IrfanView")
