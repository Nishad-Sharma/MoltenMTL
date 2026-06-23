import Foundation
import Testing
@testable import MoltenMTL

/// A single shared device for the whole suite. `nil` on machines without a
/// Vulkan-capable GPU (e.g. headless CI), which gates the suite off via
/// `.enabled(if:)` rather than failing every test.
nonisolated(unsafe) let testDevice: MTLDevice? = MTLCreateSystemDefaultDevice()

// `.serialized` because every test submits to the one shared `VkQueue` / device;
// running them concurrently races descriptor pools and queue submission.
@Suite(.enabled(if: testDevice != nil), .serialized)
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

    // MARK: - Render pipeline

    @Test func samplerCreation() throws {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        let sampler = try #require(device.makeSamplerState(descriptor: descriptor),
                                   "sampler creation failed")
        _ = sampler
    }

    /// Builds the textured-quad pipeline used by the render tests: pos(float2) +
    /// uv(float2) + color(float4) vertex layout, standard alpha blending.
    /// Pass `depthPixelFormat` / `stencilPixelFormat` to render with a depth and/or
    /// stencil attachment.
    private func makeUIQuadPipeline(depthPixelFormat: MTLPixelFormat? = nil,
                                    stencilPixelFormat: MTLPixelFormat? = nil) throws -> MTLRenderPipelineState {
        let vertURL = try #require(Bundle.module.url(forResource: "ui_quad.vert", withExtension: "spv"),
                                   "bundled ui_quad.vert.spv resource missing")
        let fragURL = try #require(Bundle.module.url(forResource: "ui_quad.frag", withExtension: "spv"),
                                   "bundled ui_quad.frag.spv resource missing")
        let vertLibrary = try #require(device.makeLibrary(path: vertURL.path), "failed to load vertex SPIR-V")
        let fragLibrary = try #require(device.makeLibrary(path: fragURL.path), "failed to load fragment SPIR-V")

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2   // position
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[1].format = .float2   // uv
        vertexDescriptor.attributes[1].offset = 8
        vertexDescriptor.attributes[2].format = .float4   // color
        vertexDescriptor.attributes[2].offset = 16
        vertexDescriptor.layouts[0].stride = 32

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction   = vertLibrary.makeFunction(name: "main")
        descriptor.fragmentFunction = fragLibrary.makeFunction(name: "main")
        descriptor.vertexDescriptor = vertexDescriptor
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor        = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor   = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor      = .sourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat   = depthPixelFormat
        descriptor.stencilAttachmentPixelFormat = stencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    @Test func renderPipelineCreation() throws {
        _ = try makeUIQuadPipeline()
    }

    // MARK: - Depth

    @Test func depthStencilStateCreation() throws {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled  = true
        _ = device.makeDepthStencilState(descriptor: descriptor)
    }

    @Test func depthPipelineCreation() throws {
        _ = try makeUIQuadPipeline(depthPixelFormat: .depth32Float)
    }

    @Test func stencilPipelineCreation() throws {
        _ = try makeUIQuadPipeline(depthPixelFormat: .depth32Float_stencil8,
                                   stencilPixelFormat: .depth32Float_stencil8)
    }

    /// End-to-end depth test: clear color to red and depth to 0.0, then draw the
    /// same opaque-white quad with two different compare functions. With `.less`
    /// the fragment depth (0) is not < the stored depth (0), so the quad is
    /// rejected and the red clear shows through; with `.lessEqual` it passes and
    /// the quad is drawn white. This exercises the full depth path — attachment
    /// barrier, `pDepthAttachment`, and the dynamic `vkCmdSetDepth*` state.
    @Test func renderDepthTestRejectsAndAccepts() throws {
        let pso = try makeUIQuadPipeline(depthPixelFormat: .depth32Float)

        let size = 64
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
        colorDescriptor.usage = .renderTarget
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float, width: size, height: size, mipmapped: false)
        depthDescriptor.usage = .renderTarget

        // 4×4 white sampled texture, opaque-white tint and vertex colors so the
        // quad composites as solid white when it passes the depth test.
        let whiteDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        whiteDescriptor.usage = .shaderRead
        let whiteTexture = try #require(device.makeTexture(descriptor: whiteDescriptor))
        let whitePixels = [UInt8](repeating: 255, count: 4 * 4 * 4)
        whitePixels.withUnsafeBytes { bytes in
            whiteTexture.replace(region: .make2D(width: 4, height: 4),
                                 withBytes: bytes.baseAddress!, bytesPerRow: 4 * 4)
        }
        let sampler = try #require(device.makeSamplerState(descriptor: MTLSamplerDescriptor()))
        let queue   = try #require(device.makeCommandQueue())

        // Full-screen opaque-white quad (alpha = 1).
        let vertices: [Float] = [
            -1, -1, 0, 0, 1, 1, 1, 1,
             1, -1, 1, 0, 1, 1, 1, 1,
             1,  1, 1, 1, 1, 1, 1, 1,
            -1, -1, 0, 0, 1, 1, 1, 1,
             1,  1, 1, 1, 1, 1, 1, 1,
            -1,  1, 0, 1, 1, 1, 1, 1,
        ]
        let tint: [Float] = [1, 1, 1, 1]

        func drawQuad(compare: MTLCompareFunction) throws -> [UInt8] {
            let color = try #require(device.makeTexture(descriptor: colorDescriptor))
            let depth = try #require(device.makeTexture(descriptor: depthDescriptor))

            let passDescriptor = MTLRenderPassDescriptor()
            passDescriptor.colorAttachments[0].texture    = color
            passDescriptor.colorAttachments[0].loadAction = .clear
            passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1)
            passDescriptor.depthAttachment.texture    = depth
            passDescriptor.depthAttachment.loadAction = .clear
            passDescriptor.depthAttachment.clearDepth = 0.0

            let depthDesc = MTLDepthStencilDescriptor()
            depthDesc.depthCompareFunction = compare
            depthDesc.isDepthWriteEnabled  = true
            let depthState = device.makeDepthStencilState(descriptor: depthDesc)

            let cmd = try #require(queue.makeCommandBuffer())
            let encoder = try #require(cmd.makeRenderCommandEncoder(descriptor: passDescriptor))
            encoder.setRenderPipelineState(pso)
            encoder.setDepthStencilState(depthState)
            encoder.setFragmentTexture(whiteTexture, index: 0)
            encoder.setFragmentSamplerState(sampler, index: 0)
            tint.withUnsafeBytes { bytes in
                encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 1)
            }
            let vertexBuffer = try #require(vertices.withUnsafeBytes { bytes in
                device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count)
            })
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()

            let readback = try #require(device.makeBuffer(length: size * size * 4,
                                                          options: .storageModeShared))
            let blit = try #require(cmd.makeBlitCommandEncoder())
            blit.copy(from: color, sourceSlice: 0, sourceLevel: 0,
                      sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: size, height: size),
                      to: readback, destinationOffset: 0,
                      destinationBytesPerRow: size * 4,
                      destinationBytesPerImage: size * size * 4)
            blit.endEncoding()
            cmd.commit()
            cmd.waitUntilCompleted()

            let ptr = readback.contents().bindMemory(to: UInt8.self, capacity: size * size * 4)
            return Array(UnsafeBufferPointer(start: ptr, count: size * size * 4))
        }

        let center = ((size / 2) * size + size / 2) * 4

        // .less: 0 < 0 is false → fragment rejected → red clear shows through.
        let rejected = try drawQuad(compare: .less)
        #expect(Int(rejected[center + 0]) >= 250, ".less: red clear should remain (R high)")
        #expect(Int(rejected[center + 1]) <= 5,   ".less: quad should be rejected (G low)")

        // .lessEqual: 0 <= 0 is true → fragment passes → white quad drawn.
        let accepted = try drawQuad(compare: .lessEqual)
        #expect(Int(accepted[center + 0]) >= 250, ".lessEqual: quad drawn (R high)")
        #expect(Int(accepted[center + 1]) >= 250, ".lessEqual: quad drawn (G high)")
        #expect(Int(accepted[center + 2]) >= 250, ".lessEqual: quad drawn (B high)")
    }

    /// End-to-end stencil masking in a single render pass with a combined
    /// `depth32Float_stencil8` attachment. Pass 1 stamps stencil = 1 into the left
    /// half (compare `.always`, pass-op `.replace`); pass 2 draws full-screen green
    /// but only where stencil == 1 (compare `.equal`, ref 1). Result: left half
    /// green, right half the red clear. Exercises the combined-format barrier,
    /// `pStencilAttachment`, and every dynamic `vkCmdSetStencil*` command.
    @Test func renderStencilMaskOffscreen() throws {
        let pso = try makeUIQuadPipeline(depthPixelFormat: .depth32Float_stencil8,
                                         stencilPixelFormat: .depth32Float_stencil8)

        let size = 64
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
        colorDescriptor.usage = .renderTarget
        let dsDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float_stencil8, width: size, height: size, mipmapped: false)
        dsDescriptor.usage = .renderTarget

        let whiteDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        whiteDescriptor.usage = .shaderRead
        let whiteTexture = try #require(device.makeTexture(descriptor: whiteDescriptor))
        let whitePixels = [UInt8](repeating: 255, count: 4 * 4 * 4)
        whitePixels.withUnsafeBytes { bytes in
            whiteTexture.replace(region: .make2D(width: 4, height: 4),
                                 withBytes: bytes.baseAddress!, bytesPerRow: 4 * 4)
        }
        let sampler = try #require(device.makeSamplerState(descriptor: MTLSamplerDescriptor()))
        let queue   = try #require(device.makeCommandQueue())

        // White-vertex-color geometry so output color == tint.
        let leftQuad: [Float] = [
            -1, -1, 0, 0, 1, 1, 1, 1,
             0, -1, 1, 0, 1, 1, 1, 1,
             0,  1, 1, 1, 1, 1, 1, 1,
            -1, -1, 0, 0, 1, 1, 1, 1,
             0,  1, 1, 1, 1, 1, 1, 1,
            -1,  1, 0, 1, 1, 1, 1, 1,
        ]
        let fullQuad: [Float] = [
            -1, -1, 0, 0, 1, 1, 1, 1,
             1, -1, 1, 0, 1, 1, 1, 1,
             1,  1, 1, 1, 1, 1, 1, 1,
            -1, -1, 0, 0, 1, 1, 1, 1,
             1,  1, 1, 1, 1, 1, 1, 1,
            -1,  1, 0, 1, 1, 1, 1, 1,
        ]

        // A stencil descriptor applied identically to both faces (cull is off, so
        // a quad's two triangles may face either way).
        func depthStencil(compare: MTLCompareFunction,
                          pass: MTLStencilOperation,
                          writeMask: UInt32) -> MTLDepthStencilState {
            let d = MTLDepthStencilDescriptor()
            d.depthCompareFunction = .always
            for face in [d.frontFaceStencil, d.backFaceStencil] {
                face.stencilCompareFunction    = compare
                face.depthStencilPassOperation = pass
                face.readMask  = 0xFF
                face.writeMask = writeMask
            }
            return device.makeDepthStencilState(descriptor: d)
        }
        // Pass 1: write stencil = 1 everywhere the left quad covers.
        let writeState = depthStencil(compare: .always, pass: .replace, writeMask: 0xFF)
        // Pass 2: draw only where stencil == 1; never modify stencil.
        let testState  = depthStencil(compare: .equal,  pass: .keep,    writeMask: 0x00)

        let color = try #require(device.makeTexture(descriptor: colorDescriptor))
        let ds    = try #require(device.makeTexture(descriptor: dsDescriptor))

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture    = color
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1)
        passDescriptor.depthAttachment.texture      = ds
        passDescriptor.depthAttachment.loadAction   = .clear
        passDescriptor.stencilAttachment.texture    = ds
        passDescriptor.stencilAttachment.loadAction = .clear
        passDescriptor.stencilAttachment.clearStencil = 0

        let cmd = try #require(queue.makeCommandBuffer())
        let encoder = try #require(cmd.makeRenderCommandEncoder(descriptor: passDescriptor))
        encoder.setRenderPipelineState(pso)
        encoder.setFragmentTexture(whiteTexture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.setStencilReferenceValue(1)

        func draw(_ verts: [Float], tint: [Float], state: MTLDepthStencilState) throws {
            encoder.setDepthStencilState(state)
            tint.withUnsafeBytes { bytes in
                encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 1)
            }
            let vb = try #require(verts.withUnsafeBytes { bytes in
                device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count)
            })
            encoder.setVertexBuffer(vb, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }

        // Pass 1 paints the left half white and stamps stencil = 1 there.
        try draw(leftQuad, tint: [1, 1, 1, 1], state: writeState)
        // Pass 2 paints green only where stencil == 1 (the left half).
        try draw(fullQuad, tint: [0, 1, 0, 1], state: testState)
        encoder.endEncoding()

        let readback = try #require(device.makeBuffer(length: size * size * 4,
                                                      options: .storageModeShared))
        let blit = try #require(cmd.makeBlitCommandEncoder())
        blit.copy(from: color, sourceSlice: 0, sourceLevel: 0,
                  sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: size, height: size),
                  to: readback, destinationOffset: 0,
                  destinationBytesPerRow: size * 4,
                  destinationBytesPerImage: size * size * 4)
        blit.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()

        let ptr = readback.contents().bindMemory(to: UInt8.self, capacity: size * size * 4)
        let y = size / 2
        let left  = (y * size + size / 4) * 4
        let right = (y * size + 3 * size / 4) * 4

        // Left half: stencil passed → green over-painted.
        #expect(Int(ptr[left + 0]) <= 5,   "left: stencil-passed pixel should be green (R low)")
        #expect(Int(ptr[left + 1]) >= 250, "left: stencil-passed pixel should be green (G high)")
        // Right half: stencil failed → red clear remains.
        #expect(Int(ptr[right + 0]) >= 250, "right: stencil-failed pixel should stay red (R high)")
        #expect(Int(ptr[right + 1]) <= 5,   "right: stencil-failed pixel should stay red (G low)")
    }

    /// End-to-end render: clear a 64×64 target to opaque red, draw a half-alpha
    /// white textured quad over the left half with standard alpha blending, read
    /// the pixels back, and check the blend on both halves. Runs a non-indexed
    /// and an indexed pass and expects identical results.
    @Test func renderBlendedQuadOffscreen() throws {
        let pso = try makeUIQuadPipeline()

        let size = 64
        let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
        targetDescriptor.usage = .renderTarget

        // 4×4 all-white sampled texture; replace() leaves it in SHADER_READ_ONLY.
        let whiteDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        whiteDescriptor.usage = .shaderRead
        let whiteTexture = try #require(device.makeTexture(descriptor: whiteDescriptor))
        let whitePixels = [UInt8](repeating: 255, count: 4 * 4 * 4)
        whitePixels.withUnsafeBytes { bytes in
            whiteTexture.replace(region: .make2D(width: 4, height: 4),
                                 withBytes: bytes.baseAddress!, bytesPerRow: 4 * 4)
        }

        let sampler = try #require(device.makeSamplerState(descriptor: MTLSamplerDescriptor()))
        let queue   = try #require(device.makeCommandQueue())

        // Quad over the left half of NDC (x ∈ [-1, 0]), half-alpha white.
        // Interleaved layout matching the pipeline: pos.xy, uv, rgba.
        let v0: [Float] = [-1, -1, 0, 1, 1, 1, 1, 0.5]
        let v1: [Float] = [ 0, -1, 1, 1, 1, 1, 1, 0.5]
        let v2: [Float] = [ 0,  1, 1, 0, 1, 1, 1, 0.5]
        let v3: [Float] = [-1,  1, 0, 0, 1, 1, 1, 0.5]
        let tint: [Float] = [1, 1, 1, 1]

        func drawQuad(indexed: Bool) throws -> [UInt8] {
            let target = try #require(device.makeTexture(descriptor: targetDescriptor))

            let passDescriptor = MTLRenderPassDescriptor()
            passDescriptor.colorAttachments[0].texture    = target
            passDescriptor.colorAttachments[0].loadAction = .clear
            passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1)

            let cmd = try #require(queue.makeCommandBuffer())
            let encoder = try #require(cmd.makeRenderCommandEncoder(descriptor: passDescriptor))
            encoder.setRenderPipelineState(pso)
            encoder.setFragmentTexture(whiteTexture, index: 0)
            encoder.setFragmentSamplerState(sampler, index: 0)
            tint.withUnsafeBytes { bytes in
                encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 1)
            }

            if indexed {
                let vertices = v0 + v1 + v2 + v3
                let indices: [UInt16] = [0, 1, 2, 0, 2, 3]
                let vertexBuffer = try #require(vertices.withUnsafeBytes { bytes in
                    device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count)
                })
                let indexBuffer = try #require(indices.withUnsafeBytes { bytes in
                    device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count)
                })
                encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                encoder.drawIndexedPrimitives(type: .triangle, indexCount: 6,
                                              indexType: .uint16, indexBuffer: indexBuffer)
            } else {
                let vertices = v0 + v1 + v2 + v0 + v2 + v3
                let vertexBuffer = try #require(vertices.withUnsafeBytes { bytes in
                    device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count)
                })
                encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            }
            encoder.endEncoding()

            let readback = try #require(device.makeBuffer(length: size * size * 4,
                                                          options: .storageModeShared))
            let blit = try #require(cmd.makeBlitCommandEncoder())
            blit.copy(from: target, sourceSlice: 0, sourceLevel: 0,
                      sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: size, height: size),
                      to: readback, destinationOffset: 0,
                      destinationBytesPerRow: size * 4,
                      destinationBytesPerImage: size * size * 4)
            blit.endEncoding()
            cmd.commit()
            cmd.waitUntilCompleted()

            let ptr = readback.contents().bindMemory(to: UInt8.self, capacity: size * size * 4)
            return Array(UnsafeBufferPointer(start: ptr, count: size * size * 4))
        }

        // blend(red, white·0.5): rgb = 0.5·white + 0.5·red, a = 0.5·0.5 + 0.5·1
        let expectedLeft:  [Int] = [255, 128, 128, 191]
        let expectedRight: [Int] = [255, 0, 0, 255]

        func checkPixels(_ pixels: [UInt8], label: String) {
            // One sample row is enough — the quad spans the full height.
            let y = size / 2
            for (x, expected) in [(size / 4, expectedLeft), (3 * size / 4, expectedRight)] {
                let base = (y * size + x) * 4
                for channel in 0..<4 {
                    let actual = Int(pixels[base + channel])
                    #expect(abs(actual - expected[channel]) <= 2,
                            "\(label): pixel (\(x), \(y)) channel \(channel) was \(actual), expected \(expected[channel])")
                }
            }
        }

        checkPixels(try drawQuad(indexed: false), label: "non-indexed")
        checkPixels(try drawQuad(indexed: true),  label: "indexed")
    }

}
