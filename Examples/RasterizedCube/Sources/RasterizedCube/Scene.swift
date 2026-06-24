import Foundation
import MoltenMTL

// MARK: - Render-agnostic scene model
//
// Copied from the RayTracedCube example so both renderers display the identical scene.
// The only raster-specific additions are the camera view/projection matrices and the
// small `float4x4` they need (the ray tracer only needed a camera basis).

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

// MARK: - Matrices (column-major, dependency-free)

/// Column-major 4×4 matrix mirroring a GLSL `mat4` (so it uploads directly into a
/// uniform block). Right-handed view/projection with a 0…1 depth range (Vulkan/Metal).
struct float4x4 {
    var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)

    init(_ c0: SIMD4<Float>, _ c1: SIMD4<Float>, _ c2: SIMD4<Float>, _ c3: SIMD4<Float>) {
        columns = (c0, c1, c2, c3)
    }

    static var identity: float4x4 {
        float4x4(SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, 0, 0, 1))
    }

    /// Matrix · column-vector.
    static func * (m: float4x4, v: SIMD4<Float>) -> SIMD4<Float> {
        m.columns.0 * v.x + m.columns.1 * v.y + m.columns.2 * v.z + m.columns.3 * v.w
    }

    /// Matrix · matrix (each result column = self · other's column).
    static func * (a: float4x4, b: float4x4) -> float4x4 {
        float4x4(a * b.columns.0, a * b.columns.1, a * b.columns.2, a * b.columns.3)
    }

    /// Right-handed look-at; camera looks down −Z in view space.
    static func lookAt(eye: Vec3, target: Vec3, up: Vec3) -> float4x4 {
        let f = (target - eye).normalized
        let s = f.cross(up).normalized
        let u = s.cross(f)
        return float4x4(
            SIMD4(s.x, u.x, -f.x, 0),
            SIMD4(s.y, u.y, -f.y, 0),
            SIMD4(s.z, u.z, -f.z, 0),
            SIMD4(-s.dot(eye), -u.dot(eye), f.dot(eye), 1))
    }

    /// Right-handed perspective with depth in [0, 1] (+Y up in clip; the render encoder
    /// records a negative-height viewport so this matches Metal's convention).
    static func perspective(fovYDegrees: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let f = 1 / tan(fovYDegrees * .pi / 180 * 0.5)
        return float4x4(
            SIMD4(f / aspect, 0, 0, 0),
            SIMD4(0, f, 0, 0),
            SIMD4(0, 0, far / (near - far), -1),
            SIMD4(0, 0, (near * far) / (near - far), 0))
    }
}

extension MTLPackedFloat4x3 {
    /// As a column-major model matrix (the implicit 4th row is 0,0,0,1).
    var modelMatrix: float4x4 {
        let c = columns
        return float4x4(
            SIMD4(c.0.x, c.0.y, c.0.z, 0),
            SIMD4(c.1.x, c.1.y, c.1.z, 0),
            SIMD4(c.2.x, c.2.y, c.2.z, 0),
            SIMD4(c.3.x, c.3.y, c.3.z, 1))
    }
}

/// A perspective camera. Stores high-level parameters; `basis` derives the ray vectors,
/// while `viewMatrix`/`projectionMatrix` drive the raster pipeline.
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

    var viewMatrix: float4x4 { .lookAt(eye: eye, target: target, up: up) }
    var projectionMatrix: float4x4 {
        .perspective(fovYDegrees: fovYDegrees, aspect: aspect, near: 0.1, far: 100)
    }
    /// Combined view · projection for `gl_Position = viewProj * model * pos`.
    var viewProjectionMatrix: float4x4 { projectionMatrix * viewMatrix }
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

/// CPU-side RGBA8 image, row-major and tightly packed. Uploaded to an `MTLTexture`.
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
/// per `vertices` entry), interpolated across triangles.
struct Mesh {
    var vertices: [MTLPackedFloat3]
    var uvs: [SIMD2<Float>]
    var normals: [SIMD4<Float>]
    var indices: [UInt32]
}

/// One renderable: a mesh placed by a transform with a material. One draw call.
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
    /// Identity rotation/scale with a translation.
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
    /// Object 0 is the cube (textured), object 1 is the plane (solid).
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
