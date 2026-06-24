import Foundation
import MoltenMTL

// raytrace.spv is compiled from Shaders/raytrace.comp by the CompileShaders build
// plugin and bundled as a resource, so `swift run` produces it automatically.
guard let shaderURL = Bundle.module.url(forResource: "raytrace", withExtension: "spv") else {
    fatalError("raytrace.spv not found in bundle — the CompileShaders plugin did not run.")
}

guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("No Vulkan-capable GPU found")
}

// The scene (camera, light, geometry, materials) lives in Scene.swift — a
// render-agnostic description shared with a future rasterized example.
let scene = Scene.demo()
let queue = device.makeCommandQueue()!

// MARK: - Bottom-level acceleration structures (one per object)

@MainActor //why
func buildBLAS(_ mesh: Mesh) -> (blas: MTLAccelerationStructure, indexBuffer: MTLBuffer) {
    let vertexBuffer = device.makeBuffer(
        bytes: mesh.vertices,
        length: mesh.vertices.count * MemoryLayout<MTLPackedFloat3>.stride,
        options: .storageModeShared)!
    let indexBuffer = device.makeBuffer(
        bytes: mesh.indices,
        length: mesh.indices.count * MemoryLayout<UInt32>.stride,
        options: .storageModeShared)!

    let geom = MTLAccelerationStructureTriangleGeometryDescriptor()
    geom.vertexBuffer  = vertexBuffer
    geom.vertexCount   = mesh.vertices.count
    geom.indexBuffer   = indexBuffer
    geom.indexType     = .uint32
    geom.triangleCount = mesh.indices.count / 3

    let desc = MTLPrimitiveAccelerationStructureDescriptor()
    desc.geometryDescriptors = [geom]

    let sizes   = device.accelerationStructureSizes(descriptor: desc)
    let blas    = device.makeAccelerationStructure(size: sizes.accelerationStructureSize)!
    let scratch = device.makeBuffer(length: sizes.buildScratchBufferSize,
                                    options: .storageModePrivate)!

    let cb  = queue.makeCommandBuffer()!
    let enc = cb.makeAccelerationStructureCommandEncoder()!
    enc.build(accelerationStructure: blas, descriptor: desc,
              scratchBuffer: scratch, scratchBufferOffset: 0)
    enc.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()
    return (blas, indexBuffer)
}

let built    = scene.objects.map { buildBLAS($0.mesh) }
let blasList  = built.map(\.blas)
print("BLAS built ✓")

// MARK: - Top-level acceleration structure (one instance per object)

var instances = scene.objects.enumerated().map { (i, obj) -> MTLAccelerationStructureInstanceDescriptor in
    var inst = MTLAccelerationStructureInstanceDescriptor()
    inst.accelerationStructureIndex = UInt32(i)   // index into instancedAccelerationStructures
    inst.options                    = .opaque
    inst.mask                       = 0xFF
    inst.transformationMatrix       = obj.transform
    return inst
}

let instanceBuffer = device.makeBuffer(
    bytes: &instances,
    length: instances.count * MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride,
    options: .storageModeShared)!

let tlasDesc = MTLInstanceAccelerationStructureDescriptor()
tlasDesc.instanceDescriptorBuffer        = instanceBuffer
tlasDesc.instanceCount                   = instances.count
tlasDesc.instancedAccelerationStructures = blasList

let tlasSizes   = device.accelerationStructureSizes(descriptor: tlasDesc)
let tlas        = device.makeAccelerationStructure(size: tlasSizes.accelerationStructureSize)!
let tlasScratch = device.makeBuffer(length: tlasSizes.buildScratchBufferSize,
                                    options: .storageModePrivate)!

do {
    let cb  = queue.makeCommandBuffer()!
    let enc = cb.makeAccelerationStructureCommandEncoder()!
    enc.build(accelerationStructure: tlas, descriptor: tlasDesc,
              scratchBuffer: tlasScratch, scratchBufferOffset: 0)
    enc.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()
}
print("TLAS built ✓")

// MARK: - Pipeline

guard let library  = device.makeLibrary(path: shaderURL.path),
      let function = library.makeFunction(name: "main") else {
    fatalError("Failed to load shader at \(shaderURL.path)")
}

// Reflect the SPIR-V to map bindings automatically, so the shader can use logical
// binding numbers (0 pixels, 1 TLAS, 2 uniforms, 3 materials) regardless of type order.
let pso = try device.makeComputePipelineState(function: function)

// MARK: - Scene data buffers

let imageSize  = 256
let pixelCount = imageSize * imageSize
let pixelBuffer = device.makeBuffer(
    length: pixelCount * 4 * MemoryLayout<Float>.stride,
    options: .storageModeShared)!
let pixelPtr = pixelBuffer.contents().bindMemory(to: Float.self, capacity: pixelCount * 4)

var uniforms = scene.uniforms()
let materials = scene.instanceMaterials()
let materialBuffer = device.makeBuffer(
    bytes: materials,
    length: materials.count * MemoryLayout<GPUMaterial>.stride,
    options: .storageModeShared)!

// Cube texture: a real rgba8 image uploaded to an MTLTexture, read in the shader via
// imageLoad. Usage includes .shaderWrite so the image gets VK_IMAGE_USAGE_STORAGE_BIT
// (required to bind as a storage image), even though we only read it.
let texData = scene.texture
let texDesc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .rgba8Unorm, width: texData.width, height: texData.height, mipmapped: false)
texDesc.usage = [.shaderRead, .shaderWrite]
let cubeTexture = device.makeTexture(descriptor: texDesc)!
texData.pixels.withUnsafeBytes {
    cubeTexture.replace(
        region: .make2D(width: texData.width, height: texData.height),
        mipmapLevel: 0,
        withBytes: $0.baseAddress!,
        bytesPerRow: texData.width * 4)
}

// Per-vertex UV texturing needs the textured object's index + UV buffers in the shader
// to fetch and barycentrically interpolate UVs. Only the cube (object 0) is textured;
// reuse its BLAS index buffer and upload its UVs. (Multiple textured meshes would need
// per-geometry buffer addresses / bindless instead.)
let cubeIndexBuffer = built[0].indexBuffer
let cubeUVs = scene.objects[0].mesh.uvs
let cubeUVBuffer = device.makeBuffer(
    bytes: cubeUVs,
    length: cubeUVs.count * MemoryLayout<SIMD2<Float>>.stride,
    options: .storageModeShared)!
let cubeNormals = scene.objects[0].mesh.normals
let cubeNormalBuffer = device.makeBuffer(
    bytes: cubeNormals,
    length: cubeNormals.count * MemoryLayout<SIMD4<Float>>.stride,
    options: .storageModeShared)!

// MARK: - Dispatch

let cb  = queue.makeCommandBuffer()!
let enc = cb.makeComputeCommandEncoder()!
enc.setComputePipelineState(pso)
enc.setBuffer(pixelBuffer, offset: 0, index: 0)        // binding 0 — pixel buffer
enc.setAccelerationStructure(tlas, bufferIndex: 1)      // binding 1 — TLAS
withUnsafeBytes(of: &uniforms) {                        // binding 2 — scene uniforms
    enc.setBytes($0.baseAddress!, length: $0.count, index: 2)
}
enc.setBuffer(materialBuffer, offset: 0, index: 3)      // binding 3 — materials
enc.setTexture(cubeTexture, index: 4)                   // binding 4 — cube texture
enc.setBuffer(cubeIndexBuffer, offset: 0, index: 5)     // binding 5 — cube indices
enc.setBuffer(cubeUVBuffer, offset: 0, index: 6)        // binding 6 — cube UVs
enc.setBuffer(cubeNormalBuffer, offset: 0, index: 7)    // binding 7 — cube normals
enc.dispatchThreadgroups(
    MTLSize(width: 32, height: 32),
    threadsPerThreadgroup: MTLSize(width: 8, height: 8))
enc.endEncoding()
cb.commit()
cb.waitUntilCompleted()
print("Rays cast  ✓")

// MARK: - Readback → PPM

var ppm = Data()
ppm.append(contentsOf: "P6\n\(imageSize) \(imageSize)\n255\n".utf8)
for i in 0..<pixelCount {
    let base = i * 4
    ppm.append(UInt8(min(pixelPtr[base]     * 255.0 + 0.5, 255.0)))
    ppm.append(UInt8(min(pixelPtr[base + 1] * 255.0 + 0.5, 255.0)))
    ppm.append(UInt8(min(pixelPtr[base + 2] * 255.0 + 0.5, 255.0)))
}

let outURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("output.ppm")
try ppm.write(to: outURL)
print("Wrote \(outURL.path)")
print("Open with: any image viewer, VS Code (PPM viewer extension), or IrfanView")
