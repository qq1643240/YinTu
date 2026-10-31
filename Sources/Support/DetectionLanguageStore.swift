import Foundation

/// OCR 语言优先级（设置页可调），供 VisionAnalyzer 的识别请求使用。
enum DetectionLanguageStore {
    static let zhKey = "ocr_lang_zh"
    static let enKey = "ocr_lang_en"

    /// 未设置过 = 双语开启；全关时兜底双语（识别总得有语言）
    static var languages: [String] {
        let defaults = UserDefaults.standard
        var langs: [String] = []
        let zhOn = defaults.object(forKey: zhKey) == nil || defaults.bool(forKey: zhKey)
        let enOn = defaults.object(forKey: enKey) == nil || defaults.bool(forKey: enKey)
        if zhOn { langs.append("zh-Hans") }
        if enOn { langs.append("en-US") }
        return langs.isEmpty ? ["zh-Hans", "en-US"] : langs
    }
}
