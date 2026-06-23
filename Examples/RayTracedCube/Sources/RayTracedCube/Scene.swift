import Foundation
import MoltenMTL

// MARK: - Render-agnostic scene model
//
// This file describes the scene — camera, light, geometry, materials — without any
// reference to a particular rendering pipeline. The RayTracedCube example consumes it
// to build acceleration structures and shade with a compute shader; a future
// RasterizedCube example can reuse the same definitions (copy this file in) to drive a
// raster pipeline, so both renderers display the identical scene.

/// Minimal 3-component vector for scene-authoring math (kept separate from the
/// GPU-packed `MTLPackedFloat3` used for vertex data).
struct Vec3 {
    var x: Float
    var y: Float
    var z: Float

    init(_ x: Float, _ y: Float, _ z: Float) { self.x = x; self.y = y; self.z = z }

    static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func * (a: Vec3, s: Float) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }

    var length: Float { (x * x + y * y + z * z).squareRoot() }
    var normalized: Vec3 { let l = length; return l > 0 ? self * (1 / l) : self }

    func dot(_ b: Vec3) -> Float { x * b.x + y * b.y + z * b.z }
    func cross(_ b: Vec3) -> Vec3 {
        Vec3(y * b.z - z * b.y,
             z * b.x - x * b.z,
             x * b.y - y * b.x)
    }

    var packed: MTLPackedFloat3 { MTLPackedFloat3(x, y, z) }
    var simd4: SIMD4<Float> { SIMD4(x, y, z, 0) }
}

/// A perspective camera. Stores high-level parameters; `basis` derives the vectors a
/// ray generator needs, while view/projection matrices (for raster) can be derived
/// from the same parameters later.
struct Camera {
    var eye: Vec3
    var target: Vec3
    var up: Vec3
    var fovYDegrees: Float
    var aspect: Float

    /// Orthonormal camera basis plus `tan(fovY/2)` for ray generation.
    var basis: (forward: Vec3, right: Vec3, up: Vec3, tanHalfFov: Float) {
        let forward = (target - eye).normalized
        let right = forward.cross(up).normalized
        let trueUp = right.cross(forward)
        let tanHalfFov = tan(fovYDegrees * .pi / 180 * 0.5)
        return (forward, right, trueUp, tanHalfFov)
    }
}

struct PointLight {
    var position: Vec3
    var color: Vec3
    var intensity: Float
    /// Flat ambient term so faces turned away from the light aren't pure black.
    var ambient: Float
}

/// Surface appearance. `mode` selects how the base colour is produced:
/// `solid` uses `albedo`; `textured` samples the scene texture using the object's UVs.
struct Material {
    enum Mode: Float { case solid = 0, textured = 1 }

    var albedo: Vec3
    var mode: Mode
    var shininess: Float
    var specStrength: Float

    static func solid(_ albedo: Vec3, shininess: Float = 32, specStrength: Float = 0.4) -> Material {
        Material(albedo: albedo, mode: .solid, shininess: shininess, specStrength: specStrength)
    }

    /// Colour comes from the scene texture; `albedo` is unused (kept white).
    static func textured(shininess: Float = 24, specStrength: Float = 0.5) -> Material {
        Material(albedo: Vec3(1, 1, 1), mode: .textured, shininess: shininess, specStrength: specStrength)
    }
}

/// CPU-side RGBA8 image, row-major and tightly packed. Uploaded to an `MTLTexture`
/// by the renderer; the same pixels could feed a future raster pipeline.
struct TextureData {
    var width: Int
    var height: Int
    var pixels: [UInt8]   // width * height * 4 bytes

    /// A flat brick-and-mortar texture in a running-bond layout, generated procedurally
    /// so the example needs no asset files. Pure albedo (two solid colors, no gradient
    /// or bevel) so the scene's point light alone provides all shading.
    static func brick(size: Int = 128) -> TextureData {
        let mortar = (0.82, 0.80, 0.76)   // light warm grey
        let brick  = (0.62, 0.22, 0.16)   // brick red
        let rowH   = max(4, size / 6)
        let brickW = max(4, size / 3)
        let m      = max(1, size / 24)    // mortar thickness

        var px = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let row = y / rowH
                let off = (row % 2 == 0) ? 0 : brickW / 2   // running bond
                let bx  = (x + off) % brickW
                let by  = y % rowH
                let c   = (bx < m || by < m) ? mortar : brick

                let i = (y * size + x) * 4
                px[i + 0] = UInt8(max(0, min(255, Int(c.0 * 255))))
                px[i + 1] = UInt8(max(0, min(255, Int(c.1 * 255))))
                px[i + 2] = UInt8(max(0, min(255, Int(c.2 * 255))))
                px[i + 3] = 255
            }
        }
        return TextureData(width: size, height: size, pixels: px)
    }
}

/// Triangle mesh in object space. `uvs` and `normals` are per-vertex attributes (one
/// per `vertices` entry), interpolated across triangles. Normals use `SIMD4` (xyz, w=0)
/// to match a GLSL `vec4[]` storage buffer and avoid std430 `vec3`-array stride quirks.
struct Mesh {
    var vertices: [MTLPackedFloat3]
    var uvs: [SIMD2<Float>]
    var normals: [SIMD4<Float>]
    var indices: [UInt32]
}

/// One renderable: a mesh placed by a transform with a material. In the ray tracer
/// this becomes a BLAS + TLAS instance; in a raster pipeline it would be one draw.
struct SceneObject {
    var mesh: Mesh
    var transform: MTLPackedFloat4x3
    var materialIndex: Int
}

struct Scene {
    var camera: Camera
    var light: PointLight
    var objects: [SceneObject]
    var materials: [Material]
    /// Texture sampled by any `.textured` material (the cube, here).
    var texture: TextureData
}

// MARK: - Geometry builders

extension Mesh {
    /// Unit cube centred at the origin (−0.5…0.5), with 4 vertices per face (24 total)
    /// so each face carries its own UVs and normal. Faces in order:
    /// 0 bottom (−Y), 1 top (+Y), 2 front (−Z), 3 back (+Z), 4 left (−X), 5 right (+X).
    static func cube() -> Mesh {
        // Each face's 4 corners in (uv = (0,0),(1,0),(1,1),(0,1)) order; the texture
        // maps fully onto every face. Winding gives outward-facing front sides.
        let faces: [[MTLPackedFloat3]] = [
            // bottom (-Y)
            [MTLPackedFloat3(-0.5, -0.5,  0.5), MTLPackedFloat3( 0.5, -0.5,  0.5),
             MTLPackedFloat3( 0.5, -0.5, -0.5), MTLPackedFloat3(-0.5, -0.5, -0.5)],
            // top (+Y)
            [MTLPackedFloat3(-0.5,  0.5, -0.5), MTLPackedFloat3( 0.5,  0.5, -0.5),
             MTLPackedFloat3( 0.5,  0.5,  0.5), MTLPackedFloat3(-0.5,  0.5,  0.5)],
            // front (-Z)
            [MTLPackedFloat3(-0.5, -0.5, -0.5), MTLPackedFloat3( 0.5, -0.5, -0.5),
             MTLPackedFloat3( 0.5,  0.5, -0.5), MTLPackedFloat3(-0.5,  0.5, -0.5)],
            // back (+Z)
            [MTLPackedFloat3( 0.5, -0.5,  0.5), MTLPackedFloat3(-0.5, -0.5,  0.5),
             MTLPackedFloat3(-0.5,  0.5,  0.5), MTLPackedFloat3( 0.5,  0.5,  0.5)],
            // left (-X)
            [MTLPackedFloat3(-0.5, -0.5,  0.5), MTLPackedFloat3(-0.5, -0.5, -0.5),
             MTLPackedFloat3(-0.5,  0.5, -0.5), MTLPackedFloat3(-0.5,  0.5,  0.5)],
            // right (+X)
            [MTLPackedFloat3( 0.5, -0.5, -0.5), MTLPackedFloat3( 0.5, -0.5,  0.5),
             MTLPackedFloat3( 0.5,  0.5,  0.5), MTLPackedFloat3( 0.5,  0.5, -0.5)],
        ]
        let faceNormals: [SIMD4<Float>] = [
            SIMD4(0, -1, 0, 0), SIMD4(0, 1, 0, 0),   // bottom, top
            SIMD4(0, 0, -1, 0), SIMD4(0, 0, 1, 0),   // front, back
            SIMD4(-1, 0, 0, 0), SIMD4(1, 0, 0, 0),   // left, right
        ]
        let faceUVs: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)]

        var v: [MTLPackedFloat3] = []
        var uv: [SIMD2<Float>] = []
        var n: [SIMD4<Float>] = []
        var i: [UInt32] = []
        for (f, corners) in faces.enumerated() {
            let base = UInt32(f * 4)
            v.append(contentsOf: corners)
            uv.append(contentsOf: faceUVs)
            n.append(contentsOf: Array(repeating: faceNormals[f], count: 4))
            i.append(contentsOf: [base, base + 1, base + 2,  base, base + 2, base + 3])
        }
        return Mesh(vertices: v, uvs: uv, normals: n, indices: i)
    }

    /// Flat quad on the y = 0 plane spanning ±`halfExtent` in X and Z (normal +Y).
    static func plane(halfExtent h: Float) -> Mesh {
        let v: [MTLPackedFloat3] = [
            MTLPackedFloat3(-h, 0, -h),  // 0
            MTLPackedFloat3( h, 0, -h),  // 1
            MTLPackedFloat3( h, 0,  h),  // 2
            MTLPackedFloat3(-h, 0,  h),  // 3
        ]
        let uv: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)]
        let n: [SIMD4<Float>] = Array(repeating: SIMD4(0, 1, 0, 0), count: 4)
        let i: [UInt32] = [0, 2, 1,  0, 3, 2]
        return Mesh(vertices: v, uvs: uv, normals: n, indices: i)
    }
}

// MARK: - Transform helpers

extension MTLPackedFloat4x3 {
    /// Identity rotation/scale with a translation. Sufficient for axis-aligned
    /// placement (keeps object-space normals equal to world normals).
    static func translation(_ t: Vec3) -> MTLPackedFloat4x3 {
        MTLPackedFloat4x3(
            MTLPackedFloat3(1, 0, 0),
            MTLPackedFloat3(0, 1, 0),
            MTLPackedFloat3(0, 0, 1),
            t.packed)
    }
}

// MARK: - Demo scene

extension Scene {
    /// A cube resting on a ground plane, lit by a single point light.
    /// Object 0 is the cube, object 1 is the plane — instance order the shader relies
    /// on to pick the per-instance material.
    static func demo() -> Scene {
        let cube = SceneObject(
            mesh: .cube(),
            transform: .translation(Vec3(0, 0.5, 0)),  // sit on the plane
            materialIndex: 0)

        let plane = SceneObject(
            mesh: .plane(halfExtent: 4),
            transform: .translation(Vec3(0, 0, 0)),
            materialIndex: 1)

        let camera = Camera(
            eye: Vec3(2.5, 2.0, 3.0),
            target: Vec3(0, 0.5, 0),
            up: Vec3(0, 1, 0),
            fovYDegrees: 45,
            aspect: 1)

        let light = PointLight(
            position: Vec3(3, 5, 2),
            color: Vec3(1, 1, 1),
            intensity: 40,
            ambient: 0.08)

        let materials: [Material] = [
            .textured(),                                       // cube — brick texture
            .solid(Vec3(0.58, 0.58, 0.60), shininess: 8, specStrength: 0.05),  // plane — neutral grey
        ]

        return Scene(camera: camera, light: light,
                     objects: [cube, plane], materials: materials,
                     texture: .brick())
    }
}

// MARK: - GPU-facing layouts (std430, vec4-packed for predictable alignment)

/// Camera + light uniforms uploaded via `setBytes`. Mirror of `Uniforms` in the shader.
struct SceneUniforms {
    var eyeTanHalfFov: SIMD4<Float>      // xyz = eye,     w = tan(fovY/2)
    var forwardAspect: SIMD4<Float>      // xyz = forward, w = aspect
    var right: SIMD4<Float>              // xyz = right
    var up: SIMD4<Float>                 // xyz = up
    var lightPosIntensity: SIMD4<Float>  // xyz = light pos,   w = intensity
    var lightColorAmbient: SIMD4<Float>  // xyz = light color, w = ambient
}

/// Per-instance material, indexed by `gl_InstanceID`. Mirror of `Material` in the shader.
struct GPUMaterial {
    var albedo: SIMD4<Float>
    var props: SIMD4<Float>   // x = mode, y = shininess, z = specStrength, w = unused
}

extension Scene {
    /// Pack camera + light into the uniform layout the shader expects.
    func uniforms() -> SceneUniforms {
        let b = camera.basis
        return SceneUniforms(
            eyeTanHalfFov: SIMD4(camera.eye.x, camera.eye.y, camera.eye.z, b.tanHalfFov),
            forwardAspect: SIMD4(b.forward.x, b.forward.y, b.forward.z, camera.aspect),
            right: b.right.simd4,
            up: b.up.simd4,
            lightPosIntensity: SIMD4(light.position.x, light.position.y, light.position.z, light.intensity),
            lightColorAmbient: SIMD4(light.color.x, light.color.y, light.color.z, light.ambient))
    }

    /// One `GPUMaterial` per object, in instance order, so the shader can index by
    /// `gl_InstanceID` directly.
    func instanceMaterials() -> [GPUMaterial] {
        objects.map { obj in
            let m = materials[obj.materialIndex]
            return GPUMaterial(
                albedo: m.albedo.simd4,
                props: SIMD4(m.mode.rawValue, m.shininess, m.specStrength, 0))
        }
    }
}
