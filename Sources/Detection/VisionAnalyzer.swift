import Vision

/// 一次 Vision 通道跑三类请求：OCR 文本、条码、人脸。
/// 输出坐标已经转换为本项目的归一化坐标。
struct VisionAnalysis {
    var sensitive: [DetectedRegion] = []
    var textLines: [DetectedRegion] = []

    static let empty = VisionAnalysis()
}

enum VisionAnalyzer {
    static func analyze(cgImage: CGImage) -> VisionAnalysis {
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.recognitionLanguages = ["zh-Hans", "en-US"]

        let barcodeRequest = VNDetectBarcodesRequest()
        let faceRequest = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([textRequest, barcodeRequest, faceRequest])
        } catch {
            // Vision 整体失败：无检测结果，用户仍可手动框选
            return .empty
        }

        var analysis = VisionAnalysis()

        // OCR：行框进 textLines；文字内容交给规则检测器找电话/邮箱/证件号等
        var lines: [PatternDetector.Line] = []
        for observation in textRequest.results ?? [] {
            guard let candidate = observation.topCandidates(1).first,
                  let rect = regionFromVisionBox(observation.boundingBox) else { continue }
            lines.append(PatternDetector.Line(text: candidate.string, rect: rect))
            analysis.textLines.append(DetectedRegion(rect: rect, kind: .text, label: "文本"))
        }
        analysis.sensitive += PatternDetector().detectSensitive(in: lines)

        for observation in barcodeRequest.results ?? [] {
            guard let rect = regionFromVisionBox(observation.boundingBox) else { continue }
            analysis.sensitive.append(DetectedRegion(rect: rect, kind: .barcode, label: "条码"))
        }

        for observation in faceRequest.results ?? [] {
            guard let rect = regionFromVisionBox(observation.boundingBox) else { continue }
            analysis.sensitive.append(DetectedRegion(rect: rect, kind: .face, label: "人脸"))
        }

        return analysis
    }
}
