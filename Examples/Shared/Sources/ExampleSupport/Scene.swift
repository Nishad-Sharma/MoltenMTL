import Foundation
import MoltenMTL

// MARK: - Render-agnostic scene model
//
// Shared by both examples so they display the identical scene. Holds everything the
// ray tracer and the rasterizer both need: the camera, point light, GPU mesh buffers,
// instances, and textures.

/// A perspective camera. `viewMatrix` / `projectionMatrix` drive the raster pipeline;
/// `eye`, `target`, `up`, `fovYDegrees`, `aspect` upload directly to the ray tracer.
public struct Camera {
    public var eye: SIMD3<Float>
    public var target: SIMD3<Float>
    public var up: SIMD3<Float>
    public var fovYDegrees: Float
    public var aspect: Float

    public init(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>, fovYDegrees: Float, aspect: Float) {
        self.eye = eye; self.target = target; self.up = up
        self.fovYDegrees = fovYDegrees; self.aspect = aspect
    }

    public var viewMatrix: float4x4 { .lookAt(eye: eye, target: target, up: up) }
    public var projectionMatrix: float4x4 {
        .perspective(fovYDegrees: fovYDegrees, aspect: aspect, near: 0.1, far: 100)
    }
    /// Combined view · projection for `gl_Position = viewProj * model * pos`.
    public var viewProjectionMatrix: float4x4 { projectionMatrix * viewMatrix }
}

/// GPU layout: `(SIMD3<Float> position, SIMD3<Float> color, Float intensity, Float ambient)`
/// matches the GLSL Light block exactly under std430 — SIMD3 is 16B in Swift, matching vec4.
public struct PointLight {
    public var position:  SIMD3<Float>
    public var color:     SIMD3<Float>
    public var intensity: Float
    public var ambient:   Float

    public init(position: SIMD3<Float>, color: SIMD3<Float>, intensity: Float, ambient: Float) {
        self.position = position
        self.color = color
        self.intensity = intensity
        self.ambient = ambient
    }
}

/// Surface appearance. `textureIndex == -1` ⇒ the surface is the solid `diffuseColor`;
/// otherwise the index refers to a `TextureData` in the owning `Scene.textures` array.
public struct Material {
    public var diffuseColor: SIMD3<Float>
    public var textureIndex: Int32   // -1 = no texture; ≥ 0 = index into Scene.textures
    public var shininess: Float
    public var specStrength: Float

    public init(diffuseColor: SIMD3<Float>, textureIndex: Int32, shininess: Float, specStrength: Float) {
        self.diffuseColor = diffuseColor
        self.textureIndex = textureIndex
        self.shininess = shininess
        self.specStrength = specStrength
    }

    public static func solid(_ color: SIMD3<Float>, shininess: Float = 32, specStrength: Float = 0.4) -> Material {
        Material(diffuseColor: color, textureIndex: -1, shininess: shininess, specStrength: specStrength)
    }

    /// Colour comes from the texture at `index` in `Scene.textures`; `diffuseColor` is unused (kept white).
    public static func textured(index: Int32, shininess: Float = 24, specStrength: Float = 0.5) -> Material {
        Material(diffuseColor: SIMD3<Float>(1, 1, 1), textureIndex: index, shininess: shininess, specStrength: specStrength)
    }
}

/// Per-mesh GPU buffers: separate position / normal / uv / index buffers (the layout
/// the ray tracer's BLAS build and the rasterizer's vertex descriptor both consume).
public struct MeshBuffers {
    public let positions: MTLBuffer
    public let normals: MTLBuffer
    public let uvs: MTLBuffer
    public let indices: MTLBuffer
    public let vertexCount: Int
    public let indexCount: Int
}

/// A placed, shaded occurrence of a mesh in the scene.
public struct Instance {
    public var meshIndex: Int
    public var transform: MTLPackedFloat4x3
    public var material: Material

    public init(meshIndex: Int, transform: MTLPackedFloat4x3, material: Material) {
        self.meshIndex = meshIndex; self.transform = transform; self.material = material
    }
}

public struct Scene {
    public var camera: Camera
    public var light: PointLight
    public var meshBuffers: [MeshBuffers]
    public var instances: [Instance]
    public var textures: [TextureData]

    public init(camera: Camera, light: PointLight, meshBuffers: [MeshBuffers], instances: [Instance], textures: [TextureData] = []) {
        self.camera = camera; self.light = light; self.meshBuffers = meshBuffers
        self.instances = instances; self.textures = textures
    }
}

// MARK: - Geometry builders

extension MeshBuffers {
    /// Unit cube centred at the origin (−0.5…0.5), with 4 vertices per face (24 total)
    /// so each face carries its own UVs and normal. Faces in order:
    /// 0 bottom (−Y), 1 top (+Y), 2 front (−Z), 3 back (+Z), 4 left (−X), 5 right (+X).
    public static func cube(_ device: MTLDevice) -> MeshBuffers {
        let faces: [[MTLPackedFloat3]] = [
            [MTLPackedFloat3(-0.5, -0.5,  0.5), MTLPackedFloat3( 0.5, -0.5,  0.5),
             MTLPackedFloat3( 0.5, -0.5, -0.5), MTLPackedFloat3(-0.5, -0.5, -0.5)],  // bottom (-Y)
            [MTLPackedFloat3(-0.5,  0.5, -0.5), MTLPackedFloat3( 0.5,  0.5, -0.5),
             MTLPackedFloat3( 0.5,  0.5,  0.5), MTLPackedFloat3(-0.5,  0.5,  0.5)],  // top (+Y)
            [MTLPackedFloat3(-0.5, -0.5, -0.5), MTLPackedFloat3( 0.5, -0.5, -0.5),
             MTLPackedFloat3( 0.5,  0.5, -0.5), MTLPackedFloat3(-0.5,  0.5, -0.5)],  // front (-Z)
            [MTLPackedFloat3( 0.5, -0.5,  0.5), MTLPackedFloat3(-0.5, -0.5,  0.5),
             MTLPackedFloat3(-0.5,  0.5,  0.5), MTLPackedFloat3( 0.5,  0.5,  0.5)],  // back (+Z)
            [MTLPackedFloat3(-0.5, -0.5,  0.5), MTLPackedFloat3(-0.5, -0.5, -0.5),
             MTLPackedFloat3(-0.5,  0.5, -0.5), MTLPackedFloat3(-0.5,  0.5,  0.5)],  // left (-X)
            [MTLPackedFloat3( 0.5, -0.5, -0.5), MTLPackedFloat3( 0.5, -0.5,  0.5),
             MTLPackedFloat3( 0.5,  0.5,  0.5), MTLPackedFloat3( 0.5,  0.5, -0.5)],  // right (+X)
        ]
        let faceNormals: [SIMD4<Float>] = [
            SIMD4(0, -1, 0, 0), SIMD4(0, 1, 0, 0),
            SIMD4(0, 0, -1, 0), SIMD4(0, 0, 1, 0),
            SIMD4(-1, 0, 0, 0), SIMD4(1, 0, 0, 0),
        ]
        let faceUVs: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)]

        var v: [MTLPackedFloat3] = []
        var uv: [SIMD2<Float>] = []
        var n: [SIMD4<Float>] = []
        var idx: [UInt32] = []
        for (f, corners) in faces.enumerated() {
            let base = UInt32(f * 4)
            v.append(contentsOf: corners)
            uv.append(contentsOf: faceUVs)
            n.append(contentsOf: Array(repeating: faceNormals[f], count: 4))
            idx.append(contentsOf: [base, base + 1, base + 2,  base, base + 2, base + 3])
        }
        return MeshBuffers(
            positions: device.makeBuffer(bytes: v,   length: v.count   * MemoryLayout<MTLPackedFloat3>.stride, options: .storageModeShared)!,
            normals:   device.makeBuffer(bytes: n,   length: n.count   * MemoryLayout<SIMD4<Float>>.stride,    options: .storageModeShared)!,
            uvs:       device.makeBuffer(bytes: uv,  length: uv.count  * MemoryLayout<SIMD2<Float>>.stride,    options: .storageModeShared)!,
            indices:   device.makeBuffer(bytes: idx, length: idx.count * MemoryLayout<UInt32>.stride,          options: .storageModeShared)!,
            vertexCount: v.count, indexCount: idx.count)
    }

    /// Flat quad on the y = 0 plane spanning ±`halfExtent` in X and Z (normal +Y).
    public static func plane(halfExtent h: Float, _ device: MTLDevice) -> MeshBuffers {
        let v: [MTLPackedFloat3] = [
            MTLPackedFloat3(-h, 0, -h), MTLPackedFloat3( h, 0, -h),
            MTLPackedFloat3( h, 0,  h), MTLPackedFloat3(-h, 0,  h),
        ]
        let uv: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)]
        let n:  [SIMD4<Float>] = Array(repeating: SIMD4(0, 1, 0, 0), count: 4)
        let idx: [UInt32] = [0, 2, 1,  0, 3, 2]
        return MeshBuffers(
            positions: device.makeBuffer(bytes: v,   length: v.count   * MemoryLayout<MTLPackedFloat3>.stride, options: .storageModeShared)!,
            normals:   device.makeBuffer(bytes: n,   length: n.count   * MemoryLayout<SIMD4<Float>>.stride,    options: .storageModeShared)!,
            uvs:       device.makeBuffer(bytes: uv,  length: uv.count  * MemoryLayout<SIMD2<Float>>.stride,    options: .storageModeShared)!,
            indices:   device.makeBuffer(bytes: idx, length: idx.count * MemoryLayout<UInt32>.stride,          options: .storageModeShared)!,
            vertexCount: v.count, indexCount: idx.count)
    }
}

// MARK: - Demo scene

extension Scene {
    /// A cube resting on a ground plane, lit by a single point light. The cube samples
    /// an orange texture; the plane is solid grey (no texture).
    public static func demo(_ device: MTLDevice) -> Scene {
        let textures: [TextureData] = [.solid(SIMD3<Float>(1.0, 0.45, 0.15))]

        let meshBuffers: [MeshBuffers] = [.cube(device), .plane(halfExtent: 4, device)]

        let instances: [Instance] = [
            Instance(meshIndex: 0,
                     transform: .translation(SIMD3<Float>(0, 0.5, 0)),
                     material:  .textured(index: 0)),
            Instance(meshIndex: 1,
                     transform: .translation(SIMD3<Float>(0, 0, 0)),
                     material:  .solid(SIMD3<Float>(0.58, 0.58, 0.60), shininess: 8, specStrength: 0.05)),
        ]

        let camera = Camera(
            eye:    SIMD3<Float>(2.5, 2.0, 3.0),
            target: SIMD3<Float>(0, 0.5, 0),
            up:     SIMD3<Float>(0, 1, 0),
            fovYDegrees: 45,
            aspect: 1)

        let light = PointLight(
            position:  SIMD3<Float>(3, 5, 2),
            color:     SIMD3<Float>(1, 1, 1),
            intensity: 40,
            ambient:   0.08)

        return Scene(camera: camera, light: light, meshBuffers: meshBuffers, instances: instances, textures: textures)
    }
}

