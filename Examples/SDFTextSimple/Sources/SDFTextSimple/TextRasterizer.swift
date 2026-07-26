import Foundation
import MoltenMTL

/// Draws MSDF text with an instanced render pipeline: 6 vertices (two triangles of
/// a unit quad) × one instance per glyph, corners expanded on the GPU from
/// per-glyph records and the font's em-unit glyph table. Immediate-mode: each
/// pass runs the pen walk and uploads a transient glyph buffer — right for
/// examples and small UIs; a retained layer (cached buffers + dirty flags) can be
/// built on top when text persists across frames.
final class TextRasterizer {
    private let pipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private let device: MTLDevice

    var fonts: [String: FontAtlas] = [:]

    var elements: [TextElement] = []

    /// `pixelFormat` must match the render target the text will be drawn into.
    /// Prefer an sRGB format: the hardware then blends in linear light, without
    /// which anti-aliased edge pixels render at roughly half their correct
    /// brightness (thin, dark-fringed strokes).
    init(device: MTLDevice, pixelFormat: MTLPixelFormat) throws {
        self.device = device

        // The shaders are compiled to SPIR-V by the CompileShaders plugin and
        // bundled as this module's resources.
        guard let vertURL = Bundle.module.url(forResource: "TextRaster.vert", withExtension: "spv"),
              let fragURL = Bundle.module.url(forResource: "TextRaster.frag", withExtension: "spv"),
              let vertLib = device.makeLibrary(path: vertURL.path),
              let fragLib = device.makeLibrary(path: fragURL.path),
              let vertFn  = vertLib.makeFunction(name: "main"),
              let fragFn  = fragLib.makeFunction(name: "main") else {
            throw SDFTextError.shaderLoadFailure("failed to load compiled TextRaster.vert/TextRaster.frag SPIR-V from the bundle — did the CompileShaders plugin run?")
        }

        // No vertex descriptor: there are no vertex attributes. The vertex shader
        // reads the glyph records and glyph table from storage buffers and
        // generates the quad corners itself from gl_VertexIndex/gl_InstanceIndex.
        let pipeDesc = MTLRenderPipelineDescriptor()
        pipeDesc.vertexFunction   = vertFn
        pipeDesc.fragmentFunction = fragFn
        pipeDesc.colorAttachments[0].pixelFormat = pixelFormat
        // Alpha blending: the fragment shader outputs fractional alpha at glyph
        // edges (the anti-aliasing) and 0 outside the letterform, so quads
        // composite over the background instead of stamping opaque rectangles.
        pipeDesc.colorAttachments[0].isBlendingEnabled           = true
        pipeDesc.colorAttachments[0].sourceRGBBlendFactor        = .sourceAlpha
        pipeDesc.colorAttachments[0].destinationRGBBlendFactor   = .oneMinusSourceAlpha
        pipeDesc.colorAttachments[0].sourceAlphaBlendFactor      = .sourceAlpha
        pipeDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: pipeDesc)

        // Bilinear filtering interpolates *distances*, which stay meaningful
        // between texels — that is what lets one atlas render crisply at any size.
        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        sampler = device.makeSamplerState(descriptor: samplerDesc)!
    }

    func encodePass(commandBuffer: MTLCommandBuffer, target: MTLTexture) {
        guard !elements.isEmpty else { return }

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture     = target
        passDesc.colorAttachments[0].loadAction  = .load     // draw over the clear pass encoded in main.swift
        passDesc.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.label = "SDF Text"
        let passParams = TextPassParams(screen: SIMD4(Float(target.width), Float(target.height), 0, 0))
        withUnsafeBytes(of: passParams) { encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: TextBinding.passParams) }

        for (fontName, items) in Dictionary(grouping: elements, by: \.font) {
            drawFont(items, font: fontName, encoder: encoder)
        }
        encoder.endEncoding()
    }

    private func drawFont(_ items: [TextElement], font: String, encoder: MTLRenderCommandEncoder) {
        guard let fontAtlas = fonts[font] else {
            preconditionFailure("font '\(font)' was not registered in `fonts` before encoding")
        }
        var chars: [GlyphInstance] = []
        for item in items {
            chars.append(contentsOf: penWalk(item.text, atlas: fontAtlas,
                                             sizePx: item.sizePx, at: item.position))
        }
        guard !chars.isEmpty else { return }

        encoder.setRenderPipelineState(pipeline)

        let charBuffer = chars.withUnsafeBytes {
            device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)!
        }
        encoder.setVertexBuffer(charBuffer, offset: 0, index: TextBinding.chars)
        encoder.setVertexBuffer(fontAtlas.glyphQuadBuffer, offset: 0, index: TextBinding.glyphQuads)
        encoder.setFragmentTexture(fontAtlas.atlasTexture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)

        let textParams = SDFDecodeParams(distanceRange: SIMD4(fontAtlas.distanceRange, 0, 0, 0))
        withUnsafeBytes(of: textParams) { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: TextBinding.sdfParams) }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6,
                               instanceCount: chars.count)
    }
}

/// Walks the pen across a string, resolving each glyph to its absolute pixel position.
/// This is the one inherently sequential step (each x depends on every advance before
/// it); it runs once per line on the CPU, and only the per-glyph result is uploaded.
func penWalk(_ text: String, atlas: FontAtlas, sizePx: Float,
             at position: SIMD2<Float>) -> [GlyphInstance] {
    var chars: [GlyphInstance] = []
    chars.reserveCapacity(text.unicodeScalars.count)
    var penX = position.x
    for scalar in text.unicodeScalars {
        let glyphIndex = atlas.getGlyphIndex(of: scalar)
        chars.append(GlyphInstance(glyphIndex: glyphIndex, sizePx: sizePx,
                                   position: SIMD2(penX, position.y)))
        penX += atlas.glyphAdvances[Int(glyphIndex)] * sizePx
    }
    return chars
}
