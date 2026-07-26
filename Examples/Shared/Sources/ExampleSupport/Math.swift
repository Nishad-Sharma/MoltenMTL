import Foundation
import MoltenMTL

// MARK: - Matrices

/// Column-major 4×4 matrix mirroring a GLSL `mat4` (so it uploads directly into a
/// uniform block). Right-handed view/projection with a 0…1 depth range (Vulkan/Metal).
public struct float4x4 {
    public var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)

    public init(_ c0: SIMD4<Float>, _ c1: SIMD4<Float>, _ c2: SIMD4<Float>, _ c3: SIMD4<Float>) {
        columns = (c0, c1, c2, c3)
    }

    /// Matrix · column-vector.
    public static func * (m: float4x4, v: SIMD4<Float>) -> SIMD4<Float> {
        m.columns.0 * v.x + m.columns.1 * v.y + m.columns.2 * v.z + m.columns.3 * v.w
    }

    /// Matrix · matrix (each result column = self · other's column).
    public static func * (a: float4x4, b: float4x4) -> float4x4 {
        float4x4(a * b.columns.0, a * b.columns.1, a * b.columns.2, a * b.columns.3)
    }

    /// Right-handed look-at; camera looks down −Z in view space.
    public static func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
        let f = simd3Normalize(target - eye)
        let s = simd3Normalize(simd3Cross(f, up))
        let u = simd3Cross(s, f)
        return float4x4(
            SIMD4(s.x, u.x, -f.x, 0),
            SIMD4(s.y, u.y, -f.y, 0),
            SIMD4(s.z, u.z, -f.z, 0),
            SIMD4(-simd3Dot(s, eye), -simd3Dot(u, eye), simd3Dot(f, eye), 1))
    }

    /// Right-handed perspective with depth in [0, 1].
    public static func perspective(fovYDegrees: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let f = Float(1.0 / tan(Double(fovYDegrees) * .pi / 360.0))
        return float4x4(
            SIMD4(f / aspect, 0, 0, 0),
            SIMD4(0, f, 0, 0),
            SIMD4(0, 0, far / (near - far), -1),
            SIMD4(0, 0, (near * far) / (near - far), 0))
    }
}

// MARK: - MTLPackedFloat4x3 helpers

extension MTLPackedFloat4x3 {
    /// Identity rotation/scale with a translation.
    public static func translation(_ t: SIMD3<Float>) -> MTLPackedFloat4x3 {
        MTLPackedFloat4x3(
            MTLPackedFloat3(1, 0, 0),
            MTLPackedFloat3(0, 1, 0),
            MTLPackedFloat3(0, 0, 1),
            MTLPackedFloat3(t.x, t.y, t.z))
    }

    /// As a column-major model matrix (the implicit 4th row is 0,0,0,1).
    public var modelMatrix: float4x4 {
        let c = columns
        return float4x4(
            SIMD4(c.0.x, c.0.y, c.0.z, 0),
            SIMD4(c.1.x, c.1.y, c.1.z, 0),
            SIMD4(c.2.x, c.2.y, c.2.z, 0),
            SIMD4(c.3.x, c.3.y, c.3.z, 1))
    }
}

// MARK: - Color

public func srgbToLinear(_ c: SIMD4<Float>) -> SIMD4<Float> {
    func lin(_ v: Float) -> Float {
        v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    return SIMD4(lin(c.x), lin(c.y), lin(c.z), c.w)
}

// MARK: - Private SIMD3 helpers (avoid importing simd to prevent float4x4 typealias conflict)

private func simd3Dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
    a.x * b.x + a.y * b.y + a.z * b.z
}

private func simd3Cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3(a.y * b.z - a.z * b.y,
          a.z * b.x - a.x * b.z,
          a.x * b.y - a.y * b.x)
}

private func simd3Normalize(_ v: SIMD3<Float>) -> SIMD3<Float> {
    v * (1.0 / Float(sqrt(Double(simd3Dot(v, v)))))
}
