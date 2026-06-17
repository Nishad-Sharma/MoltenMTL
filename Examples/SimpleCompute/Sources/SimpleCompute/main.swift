import Foundation
import MoltenMTL

let shaderURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Shaders/add.spv")

guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("No Vulkan-capable GPU found")
}

guard let library  = device.makeLibrary(path: shaderURL.path),
      let function = library.makeFunction(name: "main") else {
    fatalError("Failed to load shader at \(shaderURL.path)")
}
let pso = try device.makeComputePipelineState(function: function)

// Buffer: 64 x UInt32 filled with 1, 2, 3, ...
let count  = 64
let buffer = device.makeBuffer(length: count * MemoryLayout<UInt32>.size,
                               options: .storageModeShared)!
let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
for i in 0..<count { ptr[i] = UInt32(i + 1) }

print("Input:  \((0..<8).map { ptr[$0] })")

let queue   = device.makeCommandQueue()!
let cmdBuf  = queue.makeCommandBuffer()!
let encoder = cmdBuf.makeComputeCommandEncoder()!

encoder.setComputePipelineState(pso)
encoder.setBuffer(buffer, offset: 0, index: 0)
encoder.dispatchThreadgroups(MTLSize(width: count), threadsPerThreadgroup: MTLSize(width: count))
encoder.endEncoding()

cmdBuf.commit()
cmdBuf.waitUntilCompleted()

print("Output: \((0..<8).map { ptr[$0] })")
