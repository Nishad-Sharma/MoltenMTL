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

// MARK: - Pipeline

guard let library  = device.makeLibrary(path: shaderURL.path),
      let function = library.makeFunction(name: "main") else {
    fatalError("Failed to load shader at \(shaderURL.path)")
}
let pso = try device.makeComputePipelineState(function: function)

let pixelCount = imageSize * imageSize
let ouputPixelBuffer = device.makeBuffer(length: pixelCount * 4 * MemoryLayout<Float>.stride, options: .storageModeShared)!
let outputPixelPtr = ouputPixelBuffer.contents().bindMemory(to: Float.self, capacity: pixelCount * 4)

// MARK: - Scene data buffers

var camera = scene.camera
var light  = scene.light

let materials = scene.instances.map { $0.material }
let materialBuffer = device.makeBuffer(bytes: materials,
                                       length: materials.count * MemoryLayout<Material>.stride,
                                       options: .storageModeShared)!

// Per-instance mesh index (shader needs to know which mesh each instance references).
let instMeshIdxData = scene.instances.map { UInt32($0.meshIndex) }
let instMeshIdxBuffer = device.makeBuffer(bytes: instMeshIdxData,
                                          length: instMeshIdxData.count * MemoryLayout<UInt32>.stride,
                                          options: .storageModeShared)!

// Pack all meshes' vertex data into single flat buffers, tracking per-mesh ranges.
struct MeshRange { var indexStart: UInt32; var vertexStart: UInt32 }
var allIndices:  [UInt32]        = []
var allUVs:      [SIMD2<Float>]  = []
var allNormals:  [SIMD4<Float>]  = []
var meshRanges:  [MeshRange]     = []
for mesh in scene.meshBuffers {
    meshRanges.append(MeshRange(indexStart:  UInt32(allIndices.count),
                                vertexStart: UInt32(allUVs.count)))
    let ip = mesh.indices.contents().bindMemory(to: UInt32.self,       capacity: mesh.indexCount)
    allIndices.append(contentsOf: UnsafeBufferPointer(start: ip, count: mesh.indexCount))
    let up = mesh.uvs.contents().bindMemory(to: SIMD2<Float>.self,     capacity: mesh.vertexCount)
    allUVs.append(contentsOf: UnsafeBufferPointer(start: up, count: mesh.vertexCount))
    let np = mesh.normals.contents().bindMemory(to: SIMD4<Float>.self,  capacity: mesh.vertexCount)
    allNormals.append(contentsOf: UnsafeBufferPointer(start: np, count: mesh.vertexCount))
}
let rangesBuffer    = device.makeBuffer(bytes: meshRanges,
                                        length: meshRanges.count * MemoryLayout<MeshRange>.stride,
                                        options: .storageModeShared)!
let allIndicesBuffer = device.makeBuffer(bytes: allIndices,
                                         length: allIndices.count * MemoryLayout<UInt32>.stride,
                                         options: .storageModeShared)!
let allUVsBuffer    = device.makeBuffer(bytes: allUVs,
                                        length: allUVs.count * MemoryLayout<SIMD2<Float>>.stride,
                                        options: .storageModeShared)!
let allNormalsBuffer = device.makeBuffer(bytes: allNormals,
                                         length: allNormals.count * MemoryLayout<SIMD4<Float>>.stride,
                                         options: .storageModeShared)!

// Upload all scene textures; bind as an array at binding 10.
let sceneTextures = scene.textures.map {
    uploadTexture(device, $0, usage: [.shaderRead, .shaderWrite])
}

// MARK: - Acceleration structures (one BLAS per unique mesh)

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
enc.setBuffer(ouputPixelBuffer, offset: 0, index: 0)          // 0 — pixels
enc.setAccelerationStructure(tlas, bufferIndex: 1)             // 1 — TLAS
withUnsafeBytes(of: &camera) {                                 // 2 — camera
    enc.setBytes($0.baseAddress!, length: $0.count, index: 2)
}
withUnsafeBytes(of: &light) {                                  // 3 — light
    enc.setBytes($0.baseAddress!, length: $0.count, index: 3)
}
enc.setBuffer(materialBuffer,     offset: 0, index: 4)         // 4 — materials
enc.setBuffer(instMeshIdxBuffer,  offset: 0, index: 5)         // 5 — instance mesh indices
enc.setBuffer(rangesBuffer,       offset: 0, index: 6)         // 6 — mesh ranges
enc.setBuffer(allIndicesBuffer,   offset: 0, index: 7)         // 7 — all indices
enc.setBuffer(allUVsBuffer,       offset: 0, index: 8)         // 8 — all UVs
enc.setBuffer(allNormalsBuffer,   offset: 0, index: 9)         // 9 — all normals
enc.setTextures(sceneTextures,    index: 10)                   // 10 — texture array
enc.dispatchThreadgroups(MTLSize(width: 32, height: 32), threadsPerThreadgroup: MTLSize(width: 8, height: 8))
enc.endEncoding()
cb.commit()
cb.waitUntilCompleted()
print("Rays cast  ✓")

// MARK: - Readback → PPM

var output = [UInt8](repeating: 0, count: pixelCount * 3)
for i in 0..<pixelCount {
    output[i * 3 + 0] = UInt8(min(outputPixelPtr[i * 4 + 0] * 255.0 + 0.5, 255.0))
    output[i * 3 + 1] = UInt8(min(outputPixelPtr[i * 4 + 1] * 255.0 + 0.5, 255.0))
    output[i * 3 + 2] = UInt8(min(outputPixelPtr[i * 4 + 2] * 255.0 + 0.5, 255.0))
}
let outputFilePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output.ppm")
try writePPM(output, width: imageSize, height: imageSize, to: outputFilePath)
print("Wrote \(outputFilePath.path)")
