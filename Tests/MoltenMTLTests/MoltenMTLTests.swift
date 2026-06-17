import Foundation
import Testing
@testable import MoltenMTL

/// A single shared device for the whole suite. `nil` on machines without a
/// Vulkan-capable GPU (e.g. headless CI), which gates the suite off via
/// `.enabled(if:)` rather than failing every test.
nonisolated(unsafe) let testDevice: MTLDevice? = MTLCreateSystemDefaultDevice()

@Suite(.enabled(if: testDevice != nil))
struct MoltenMTLTests {

    var device: MTLDevice { testDevice! }

    @Test func deviceAndQueueCreation() throws {
        let queue = try #require(device.makeCommandQueue(), "command queue creation failed")
        let cmd = try #require(queue.makeCommandBuffer(), "command buffer creation failed")
        _ = cmd
    }

    @Test func sharedBufferReadback() throws {
        let count = 16
        let length = count * MemoryLayout<UInt32>.stride
        let buffer = try #require(device.makeBuffer(length: length, options: .storageModeShared),
                                  "shared buffer allocation failed")
        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for i in 0..<count { ptr[i] = UInt32(i * 7) }
        // Persistently-mapped shared memory should read back exactly what we wrote.
        for i in 0..<count {
            #expect(ptr[i] == UInt32(i * 7))
        }
    }

    @Test func privateBufferAllocation() throws {
        let buffer = try #require(device.makeBuffer(length: 4096, options: .storageModePrivate),
                                  "private buffer allocation failed")
        _ = buffer
    }

    /// End-to-end compute dispatch: the bundled `double.spv` kernel multiplies
    /// each element of binding-0 by two.
    @Test func computeDispatchDoublesBuffer() throws {
        let spvURL = try #require(Bundle.module.url(forResource: "double", withExtension: "spv"),
                                  "bundled double.spv resource missing")
        let library = try #require(device.makeLibrary(path: spvURL.path), "failed to load SPIR-V")
        let function = try #require(library.makeFunction(name: "main"), "missing entry point")
        let pso = try device.makeComputePipelineState(function: function)

        let count = 64
        let buffer = try #require(device.makeBuffer(length: count * MemoryLayout<UInt32>.stride,
                                                    options: .storageModeShared))
        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for i in 0..<count { ptr[i] = UInt32(i + 1) }

        let queue = try #require(device.makeCommandQueue())
        let cmd = try #require(queue.makeCommandBuffer())
        let encoder = try #require(cmd.makeComputeCommandEncoder())
        encoder.setComputePipelineState(pso)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        encoder.dispatchThreadgroups(MTLSize(width: count),
                                     threadsPerThreadgroup: MTLSize(width: count))
        encoder.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()

        for i in 0..<count {
            #expect(ptr[i] == UInt32((i + 1) * 2))
        }
    }

    @Test func blasSizeQueryAndAllocation() throws {
        let geometry = MTLAccelerationStructureTriangleGeometryDescriptor()
        geometry.vertexFormat = .float3
        geometry.vertexStride = MemoryLayout<MTLPackedFloat3>.stride
        geometry.vertexCount = 3
        geometry.indexType = .uint32
        geometry.triangleCount = 1

        let descriptor = MTLPrimitiveAccelerationStructureDescriptor()
        descriptor.geometryDescriptors = [geometry]

        let sizes = device.accelerationStructureSizes(descriptor: descriptor)
        #expect(sizes.accelerationStructureSize > 0, "BLAS size query returned zero")
        #expect(sizes.buildScratchBufferSize > 0, "BLAS scratch size query returned zero")

        let blas = try #require(device.makeAccelerationStructure(size: sizes.accelerationStructureSize),
                                "BLAS allocation failed")
        _ = blas
    }

    @Test func tlasSizeQuery() throws {
        let descriptor = MTLInstanceAccelerationStructureDescriptor()
        descriptor.instanceCount = 1

        let sizes = device.accelerationStructureSizes(descriptor: descriptor)
        #expect(sizes.accelerationStructureSize > 0, "TLAS size query returned zero")
    }
}
