import Foundation
import MoltenMTL

let shaderURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // Sources/RayTracedCube/
    .deletingLastPathComponent()   // Sources/
    .deletingLastPathComponent()   // RayTracedCube/ (example root)
    .appendingPathComponent("Shaders/raytrace.spv")

guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("No Vulkan-capable GPU found")
}


let vertices: [MTLPackedFloat3] = [
    // bottom face (y = -0.5)
    MTLPackedFloat3(-0.5, -0.5, -0.5),  // 0
    MTLPackedFloat3( 0.5, -0.5, -0.5),  // 1
    MTLPackedFloat3( 0.5, -0.5,  0.5),  // 2
    MTLPackedFloat3(-0.5, -0.5,  0.5),  // 3
    // top face (y = +0.5)
    MTLPackedFloat3(-0.5,  0.5, -0.5),  // 4
    MTLPackedFloat3( 0.5,  0.5, -0.5),  // 5
    MTLPackedFloat3( 0.5,  0.5,  0.5),  // 6
    MTLPackedFloat3(-0.5,  0.5,  0.5),  // 7
]


let indices: [UInt32] = [
    0,1,2,  0,2,3,   // bottom  (-Y)
    4,6,5,  4,7,6,   // top     (+Y)
    0,4,5,  0,5,1,   // front   (-Z)
    2,6,7,  2,7,3,   // back    (+Z)
    0,3,7,  0,7,4,   // left    (-X)
    1,5,6,  1,6,2,   // right   (+X)
]

let vertexBuffer = device.makeBuffer(
    bytes: vertices,
    length: vertices.count * MemoryLayout<MTLPackedFloat3>.stride,
    options: .storageModeShared)!

let indexBuffer = device.makeBuffer(
    bytes: indices,
    length: indices.count * MemoryLayout<UInt32>.stride,
    options: .storageModeShared)!

let triGeom = MTLAccelerationStructureTriangleGeometryDescriptor()
triGeom.vertexBuffer  = vertexBuffer
triGeom.vertexCount   = vertices.count
triGeom.indexBuffer   = indexBuffer
triGeom.indexType     = .uint32
triGeom.triangleCount = indices.count / 3

let blasDesc = MTLPrimitiveAccelerationStructureDescriptor()
blasDesc.geometryDescriptors = [triGeom]

let blasSizes   = device.accelerationStructureSizes(descriptor: blasDesc)
let blas        = device.makeAccelerationStructure(size: blasSizes.accelerationStructureSize)!
let blasScratch = device.makeBuffer(
    length: blasSizes.buildScratchBufferSize,
    options: .storageModePrivate)!

let queue = device.makeCommandQueue()!

do {
    let cb  = queue.makeCommandBuffer()!
    let enc = cb.makeAccelerationStructureCommandEncoder()!
    enc.build(accelerationStructure: blas,
              descriptor:            blasDesc,
              scratchBuffer:         blasScratch,
              scratchBufferOffset:   0)
    enc.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()
}
print("BLAS built ✓")

var instance = MTLAccelerationStructureInstanceDescriptor()
instance.accelerationStructureIndex = 0       // index into instancedAccelerationStructures
instance.options                    = .opaque
instance.mask                       = 0xFF
instance.transformationMatrix = MTLPackedFloat4x3(
    MTLPackedFloat3(1, 0, 0),   // col 0 — X basis
    MTLPackedFloat3(0, 1, 0),   // col 1 — Y basis
    MTLPackedFloat3(0, 0, 1),   // col 2 — Z basis
    MTLPackedFloat3(0, 0, 0))   // col 3 — translation (origin)

let instanceBuffer = device.makeBuffer(
    bytes: [instance],
    length: MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride,
    options: .storageModeShared)!

let tlasDesc = MTLInstanceAccelerationStructureDescriptor()
tlasDesc.instanceDescriptorBuffer        = instanceBuffer
tlasDesc.instanceCount                   = 1
tlasDesc.instancedAccelerationStructures = [blas]

let tlasSizes   = device.accelerationStructureSizes(descriptor: tlasDesc)
let tlas        = device.makeAccelerationStructure(size: tlasSizes.accelerationStructureSize)!
let tlasScratch = device.makeBuffer(
    length: tlasSizes.buildScratchBufferSize,
    options: .storageModePrivate)!

do {
    let cb  = queue.makeCommandBuffer()!
    let enc = cb.makeAccelerationStructureCommandEncoder()!
    enc.build(accelerationStructure: tlas,
              descriptor:            tlasDesc,
              scratchBuffer:         tlasScratch,
              scratchBufferOffset:   0)
    enc.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()
}
print("TLAS built ✓")

guard let library  = device.makeLibrary(path: shaderURL.path),
      let function = library.makeFunction(name: "main") else {
    fatalError("""
        Failed to load shader at \(shaderURL.path)
        Compile it first:
          glslc --target-env=vulkan1.3 Shaders/raytrace.comp -o Shaders/raytrace.spv
        """)
}


let psoDesc = MTLComputePipelineDescriptor()
psoDesc.computeFunction            = function
psoDesc.storageBufferCount         = 1   // binding 0
psoDesc.accelerationStructureCount = 1   // binding 1
let pso = try device.makeComputePipelineState(descriptor: psoDesc)

let imageSize  = 256
let pixelCount = imageSize * imageSize
let pixelBuffer = device.makeBuffer(
    length: pixelCount * 4 * MemoryLayout<Float>.stride,
    options: .storageModeShared)!
let pixelPtr = pixelBuffer.contents().bindMemory(to: Float.self, capacity: pixelCount * 4)


let cb  = queue.makeCommandBuffer()!
let enc = cb.makeComputeCommandEncoder()!
enc.setComputePipelineState(pso)
enc.setBuffer(pixelBuffer, offset: 0, index: 0)       // binding 0 — pixel buffer
enc.setAccelerationStructure(tlas, bufferIndex: 1)     // binding 1 — TLAS
enc.dispatchThreadgroups(
    MTLSize(width: 32, height: 32),
    threadsPerThreadgroup: MTLSize(width: 8, height: 8))
enc.endEncoding()
cb.commit()
cb.waitUntilCompleted()
print("Rays cast  ✓")

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
