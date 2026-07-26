import Foundation

enum SDFTextError: Error, CustomStringConvertible {
    case badJSON(String)
    case wrongType(String)
    case wrongOrientation(String)
    case binSizeMismatch(expected: Int, actual: Int)
    case shaderLoadFailure(String)

    var description: String {
        switch self {
        case .badJSON(let detail):            return "failed to decode atlas JSON — \(detail)"
        case .wrongType(let got):             return "atlas must be baked with -type mtsdf (got \(got)) — the shader's median(r,g,b) reconstruction needs multi-channel"
        case .wrongOrientation(let got):      return "atlas must be baked with -yorigin top (got \(got))"
        case .binSizeMismatch(let e, let a):  return "atlas bin is \(a) bytes, expected \(e) (width × height × 4)"
        case .shaderLoadFailure(let detail):  return detail
        }
    }
}

struct Bounds: Codable {
    var left: Float
    var bottom: Float
    var right: Float
    var top: Float
}

struct GlyphData: Codable {
    let unicode: UInt32
    let advance: Float           // em units; consumed only by the CPU pen walk
    let planeBounds: Bounds?     // quad relative to the pen, em units, used to compute glyph position relative to pen
    let atlasBounds: Bounds?     // quad in the atlas image, pixels (top-left origin)
}

struct AtlasInfo: Codable {
    var type: String          // "mtsdf"
    var distanceRange: Float  // SDF band width in atlas texels — fed to the shader
    var width: Int
    var height: Int
    var yOrigin: String       // "top" (atlasBounds are y-down, planeBounds are y-down relative to the baseline) - metal/gpu texture coords also work this way
}

private struct AtlasJSON: Codable {
    var atlas: AtlasInfo
    var glyphs: [GlyphData]
}

func decodeAtlas(jsonData: Data, binData: Data) throws -> (info: AtlasInfo, glyphs: [GlyphData]) {
    let decoded: AtlasJSON
    do {
        decoded = try JSONDecoder().decode(AtlasJSON.self, from: jsonData)
    } catch {
        throw SDFTextError.badJSON(String(describing: error))
    }
    // Only mtsdf atlases with yOrigin "top" are supported: the fragment shader
    // assumes multi-channel distances, and y-down keeps atlas and plane bounds
    // in the same orientation as GPU texture coordinates (no axis flips).
    guard decoded.atlas.type == "mtsdf" else {
        throw SDFTextError.wrongType(decoded.atlas.type)
    }
    guard decoded.atlas.yOrigin == "top" else {
        throw SDFTextError.wrongOrientation(decoded.atlas.yOrigin)
    }
    let expected = decoded.atlas.width * decoded.atlas.height * 4
    guard binData.count == expected else {
        throw SDFTextError.binSizeMismatch(expected: expected, actual: binData.count)
    }
    return (decoded.atlas, decoded.glyphs)
}
