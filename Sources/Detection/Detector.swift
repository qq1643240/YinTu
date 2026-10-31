import CoreGraphics

/// M3 预留：检测器协议。
/// 实现顺序：文本(Vision OCR) → 二维码/条形码 → 人脸 → NSDataDetector(电话/邮箱) → NL 姓名。
/// 所有实现给出的 rect 都必须是「归一化、左上原点、y 向下」，与 MaskBlock 一致。
struct DetectedRegion: Equatable {
    var rect: CGRect
    var label: String
}

protocol Detector {
    var name: String { get }
    func detect(in image: CGImage) async throws -> [DetectedRegion]
}
