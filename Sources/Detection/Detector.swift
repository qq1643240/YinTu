import CoreGraphics

/// 检测结果的区域种类。
enum RegionKind: String, Codable {
    case text
    case contact
    case face
    case barcode

    /// 是否属于"默认自动打码"的敏感类
    var isSensitive: Bool { self != .text }
}

/// 检测器输出：rect 为归一化、左上原点、y 向下（与 MaskBlock 一致）。
struct DetectedRegion: Equatable {
    var rect: CGRect
    var kind: RegionKind
    var label: String
}

protocol Detector {
    var name: String { get }
    func detect(in image: CGImage) async throws -> [DetectedRegion]
}

/// Vision 的 boundingBox 是归一化、左下原点、y 向上；转到本项目的统一坐标。
/// 过小的框（噪声）返回 nil。
func regionFromVisionBox(_ box: CGRect) -> CGRect? {
    guard box.width > 0.002, box.height > 0.002 else { return nil }
    return CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
}
