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
    /// 马赛克颗粒 / 刷子粗细 / 噪点与格子尺寸（图像宽度的比例）
    var pixelSize: Double = 0.03
    /// 模糊半径 / 光斑强度（图像宽度的比例）
    var blurRadius: Double = 0.02
    var opacity: Double = 1
    /// 圆角（相对块短边的比例，0…0.5；0.5 即圆形笔触）
    var cornerRadius: Double = 0
    /// 表情遮挡使用的 emoji
    var emoji: String = "😎"
    /// 水印参数
    var watermarkText: String = "Redacto"
    /// 水印字号（图像宽度的比例）
    var watermarkSize: Double = 0.05
    /// 水印角度（度）
    var watermarkAngle: Double = -30
    /// 水印行距（字号倍数）
    var watermarkLineSpacing: Double = 2.0
}

enum ToolKind: String, CaseIterable, Codable, Identifiable {
    case colorBlock
    case pixelate
    case blur
    case marker
    case brush
    case hideText
    case emoji
    case cityLights
    case inkStroke
    case noisyColorBlock
    case rainbowBelt
    case rainbowGrid
    case watermark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colorBlock: return "色块"
        case .pixelate: return "马赛克"
        case .blur: return "模糊"
        case .marker: return "马克笔"
        case .brush: return "刷子"
        case .hideText: return "隐藏文字"
        case .emoji: return "表情"
        case .cityLights: return "城市灯光"
        case .inkStroke: return "墨迹"
        case .noisyColorBlock: return "噪点"
        case .rainbowBelt: return "彩虹条"
        case .rainbowGrid: return "彩虹格"
        case .watermark: return "水印"
        }
    }

    var symbolName: String {
        switch self {
        case .colorBlock: return "rectangle.fill"
        case .pixelate: return "squareshape.split.3x3"
        case .blur: return "drop.fill"
        case .marker: return "highlighter"
        case .brush: return "pencil.tip"
        case .hideText: return "eye.slash"
        case .emoji: return "face.smiling"
        case .cityLights: return "lightbulb"
        case .inkStroke: return "scribble"
        case .noisyColorBlock: return "camera.filters"
        case .rainbowBelt: return "rainbow"
        case .rainbowGrid: return "grid"
        case .watermark: return "textformat"
        }
    }

    /// 参数行按组复用：同一组共用颜色+透明度
    var usesColorPalette: Bool {
        switch self {
        case .colorBlock, .marker, .brush, .inkStroke:
            return true
        default:
            return false
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
