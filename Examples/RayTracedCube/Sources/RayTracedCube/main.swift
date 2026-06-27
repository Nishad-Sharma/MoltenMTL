import Foundation
import MoltenMTL
import ExampleSupport

// MARK: - Setup

// raytrace.spv is compiled from Shaders/raytrace.comp by the CompileShaders build
// plugin and bundled as a resource, so `swift run` produces it automatically.
guard let shaderURL = Bundle.module.url(forResource: "raytrace", withExtension: "spv") else {
    fatalError("raytrace.spv not found in bundle — the CompileShaders plugin did not run.")
}
let (device, queue) = makeDeviceAndQueue()
let scene = Scene.demo(device)      // shared scene (camera, light, mesh buffers)
let imageSize = 256

// MARK: - Pipeline + scene data

guard let library  = device.makeLibrary(path: shaderURL.path),
      let function = library.makeFunction(name: "main") else {
    fatalError("Failed to load shader at \(shaderURL.path)")
}
let pso = try device.makeComputePipelineState(function: function)

let pixelCount = imageSize * imageSize
let ouputPixelBuffer = device.makeBuffer(length: pixelCount * 4 * MemoryLayout<Float>.stride, options: .storageModeShared)!
let outputPixelPtr = ouputPixelBuffer.contents().bindMemory(to: Float.self, capacity: pixelCount * 4)

var camera = scene.camera
// PointLight's layout matches the shader's Light block, so upload it directly.
var light = scene.light

let materials = scene.instances.map { $0.material }
let materialBuffer = device.makeBuffer(bytes: materials, length: materials.count * MemoryLayout<Material>.stride, options: .storageModeShared)!

// The shader samples a single textured instance and fetches its per-vertex UVs/normals.
// TODO: can only texture one mesh at the moment, need to add per-mesh texture support then we can change this
let texturedInstance = scene.instances.first { $0.material.textureIndex >= 0 }!
let texturedMesh = scene.meshBuffers[texturedInstance.meshIndex]
let texture = uploadTexture(device, scene.textures[Int(texturedInstance.material.textureIndex)], usage: [.shaderRead, .shaderWrite])

// MARK: - Acceleration structures (one BLAS + instance per mesh)
// Build one bottom-level acceleration structure (BLAS) per mesh from its triangles.
var blasList: [MTLAccelerationStructure] = []
for mesh in scene.meshBuffers {
    let geom = MTLAccelerationStructureTriangleGeometryDescriptor()
    geom.vertexBuffer  = mesh.positions
    geom.vertexCount   = mesh.vertexCount
    geom.indexBuffer   = mesh.indices
    geom.indexType     = .uint32
    geom.triangleCount = mesh.indexCount / 3

    let blasDesc = MTLPrimitiveAccelerationStructureDescriptor()
    blasDesc.geometryDescriptors = [geom]

    let sizes   = device.accelerationStructureSizes(descriptor: blasDesc)
    let blas    = device.makeAccelerationStructure(size: sizes.accelerationStructureSize)!
    let scratch = device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate)!

    let cb  = queue.makeCommandBuffer()!
    let enc = cb.makeAccelerationStructureCommandEncoder()!
    enc.build(accelerationStructure: blas, descriptor: blasDesc, scratchBuffer: scratch, scratchBufferOffset: 0)
    enc.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()
    blasList.append(blas)
}
print("BLAS built ✓")

// Build the top-level acceleration structure (TLAS): one instance per BLAS, placed by
// its mesh's transform.
let instances = scene.instances.map { inst -> MTLAccelerationStructureInstanceDescriptor in
    var d = MTLAccelerationStructureInstanceDescriptor()
    d.accelerationStructureIndex = UInt32(inst.meshIndex)
    d.options                    = .opaque
    d.mask                       = 0xFF
    d.transformationMatrix       = inst.transform
    return d
}
let instanceBuffer = device.makeBuffer(
    bytes: instances,
    length: instances.count * MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride,
    options: .storageModeShared)!

let tlasDesc = MTLInstanceAccelerationStructureDescriptor()
tlasDesc.instanceDescriptorBuffer        = instanceBuffer
tlasDesc.instanceCount                   = instances.count
tlasDesc.instancedAccelerationStructures = blasList

let tlasSizes   = device.accelerationStructureSizes(descriptor: tlasDesc)
let tlas        = device.makeAccelerationStructure(size: tlasSizes.accelerationStructureSize)!
let tlasScratch = device.makeBuffer(length: tlasSizes.buildScratchBufferSize, options: .storageModePrivate)!
do {
    let cb  = queue.makeCommandBuffer()!
    let enc = cb.makeAccelerationStructureCommandEncoder()!
    enc.build(accelerationStructure: tlas, descriptor: tlasDesc, scratchBuffer: tlasScratch, scratchBufferOffset: 0)
    enc.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()
}
print("TLAS built ✓")

// MARK: - Dispatch

let cb  = queue.makeCommandBuffer()!
let enc = cb.makeComputeCommandEncoder()!
enc.setComputePipelineState(pso)
enc.setBuffer(ouputPixelBuffer, offset: 0, index: 0)        // 0 — pixels
enc.setAccelerationStructure(tlas, bufferIndex: 1)      // 1 — TLAS
withUnsafeBytes(of: &camera) {                          // 2 — camera
    enc.setBytes($0.baseAddress!, length: $0.count, index: 2)
}
enc.setBuffer(materialBuffer, offset: 0, index: 3)      // 3 — per-instance materials
enc.setTexture(texture, index: 4)                       // 4 — cube texture
enc.setBuffer(texturedMesh.indices, offset: 0, index: 5)  // 5 — cube indices
enc.setBuffer(texturedMesh.uvs, offset: 0, index: 6)      // 6 — cube UVs
enc.setBuffer(texturedMesh.normals, offset: 0, index: 7)  // 7 — cube normals
withUnsafeBytes(of: &light) {                           // 8 — point light
    enc.setBytes($0.baseAddress!, length: $0.count, index: 8)
}
enc.dispatchThreadgroups(MTLSize(width: 32, height: 32), threadsPerThreadgroup: MTLSize(width: 8, height: 8))
enc.endEncoding()
cb.commit()
cb.waitUntilCompleted()
print("Rays cast  ✓")

// MARK: - Readback → PPM

var rgb = [UInt8](repeating: 0, count: pixelCount * 3)
for i in 0..<pixelCount {
    rgb[i * 3 + 0] = UInt8(min(outputPixelPtr[i * 4 + 0] * 255.0 + 0.5, 255.0))
    rgb[i * 3 + 1] = UInt8(min(outputPixelPtr[i * 4 + 1] * 255.0 + 0.5, 255.0))
    rgb[i * 3 + 2] = UInt8(min(outputPixelPtr[i * 4 + 2] * 255.0 + 0.5, 255.0))
}
let outURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output.ppm")
try writePPM(rgb, width: imageSize, height: imageSize, to: outURL)
print("Wrote \(outURL.path)")
