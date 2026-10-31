import CoreGraphics

/// 遮盖块。
///
/// `rect` 使用「归一化、左上原点、y 向下」的图像坐标（0…1），与手势/预览坐标一致；
/// 渲染到 CoreImage 时由 `BlockRenderer` 翻转 y（CI 是左下原点）。
/// 尺寸类参数（pixelSize/blurRadius）按「图像宽度的比例」存储，与分辨率无关。
struct MaskBlock: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ToolKind
    var rect: CGRect
    var color: RGBA = RGBA(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
    /// 马赛克颗粒大小（图像宽度的比例，0.005…0.12）
    var pixelSize: Double = 0.03
    /// 模糊半径（图像宽度的比例）
    var blurRadius: Double = 0.02
    var opacity: Double = 1
    /// 圆角（相对块短边的比例，0…0.5）
    var cornerRadius: Double = 0
}

enum ToolKind: String, CaseIterable, Codable, Identifiable {
    case colorBlock
    case pixelate
    case blur
    case marker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colorBlock: return "色块"
        case .pixelate: return "马赛克"
        case .blur: return "模糊"
        case .marker: return "马克笔"
        }
    }

    var symbolName: String {
        switch self {
        case .colorBlock: return "rectangle.fill"
        case .pixelate: return "squareshape.split.3x3"
        case .blur: return "drop.fill"
        case .marker: return "highlighter"
        }
    }
}

/// 颜色值（sRGB），与 SwiftUI/CoreImage 的转换放在 ToolPanel 与 BlockRenderer。
struct RGBA: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let ink = RGBA(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
    static let markerYellow = RGBA(red: 1, green: 0.85, blue: 0.1, alpha: 1)
}
