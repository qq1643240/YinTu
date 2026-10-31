import Foundation
import NaturalLanguage

/// 在 OCR 文本行上找敏感片段：电话、邮箱、身份证、车牌、银行卡号、人名。
/// 命中范围按字符占比映射回所在行的归一化矩形（行内等宽近似，误差可接受）。
struct PatternDetector {
    struct Line {
        let text: String
        let rect: CGRect
    }

    private enum MatchKind {
        case phone
        case email
        case idNumber
        case plate
        case bankCard
        case personName

        var label: String {
            switch self {
            case .phone: return "电话"
            case .email: return "邮箱"
            case .idNumber: return "证件号"
            case .plate: return "车牌"
            case .bankCard: return "卡号"
            case .personName: return "姓名"
            }
        }
    }

    private let plateRegex = try! NSRegularExpression(
        pattern: "[京沪深津渝冀晋蒙辽吉黑苏浙皖闽赣鲁豫鄂湘桂琼川贵云陕甘青藏宁新港澳使领][A-HJ-NP-Z][A-HJ-NP-Z0-9]{4,5}[A-HJ-NP-Z0-9挂学警港澳]?"
    )
    private let idRegex = try! NSRegularExpression(pattern: "(?<![0-9])[1-9]\\d{5}(?:19|20)\\d{2}(?:0[1-9]|1[0-2])(?:[0-2]\\d|3[01])\\d{3}[0-9Xx](?![0-9])")
    private let bankCardRegex = try! NSRegularExpression(pattern: "(?<![0-9-])(?:\\d[ -]?){12,18}\\d(?![0-9-])")
    private let mobileRegex = try! NSRegularExpression(pattern: "(?<![0-9])1[3-9]\\d{9}(?![0-9])")
    private let landlineRegex = try! NSRegularExpression(pattern: "(?<![0-9])0\\d{2,3}-?\\d{7,8}(?![0-9])")

    func detectSensitive(in lines: [Line]) -> [DetectedRegion] {
        var regions: [DetectedRegion] = []
        for line in lines {
            for (range, kind) in matches(in: line.text) {
                guard let rect = rect(for: range, in: line) else { continue }
                regions.append(DetectedRegion(rect: rect, kind: .contact, label: kind.label))
            }
        }
        return regions
    }

    // MARK: - 各类模式

    private func matches(in text: String) -> [(NSRange, MatchKind)] {
        var results: [(NSRange, MatchKind)] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        // NSDataDetector：电话与邮箱（邮箱以 link 形式给出）
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.link.rawValue) {
            for check in detector.matches(in: text, range: fullRange) {
                switch check.resultType {
                case .phoneNumber:
                    results.append((check.range, .phone))
                case .link:
                    if let url = check.url, url.scheme == "mailto" || url.absoluteString.contains("@") {
                        results.append((check.range, .email))
                    }
                default:
                    break
                }
            }
        }

        // 国内手机/座机兜底（NSDataDetector 对不带 +86 的号码可能漏检）
        for match in mobileRegex.matches(in: text, range: fullRange) {
            results.append((match.range, .phone))
        }
        for match in landlineRegex.matches(in: text, range: fullRange) {
            results.append((match.range, .phone))
        }

        for match in idRegex.matches(in: text, range: fullRange) {
            results.append((match.range, .idNumber))
        }

        for match in plateRegex.matches(in: text, range: fullRange) {
            results.append((match.range, .plate))
        }

        for match in bankCardRegex.matches(in: text, range: fullRange) {
            let digits = nsText.substring(with: match.range).filter { $0.isNumber }
            if luhnValid(digits) {
                results.append((match.range, .bankCard))
            }
        }

        // 人名：NLTagger 按词级标注（语言自动检测，中英均可）
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            if tag == .personalName {
                results.append((NSRange(range, in: text), .personName))
            }
            return true
        }

        return dedupe(results)
    }

    /// 同一类内去重叠范围，电话类同时去跨正则重复
    private func dedupe(_ matches: [(NSRange, MatchKind)]) -> [(NSRange, MatchKind)] {
        var kept: [(NSRange, MatchKind)] = []
        for match in matches.sorted(by: { $0.0.length > $1.0.length }) {
            let overlaps = kept.contains { keptMatch in
                NSIntersectionRange(keptMatch.0, match.0).length > 0
            }
            if !overlaps {
                kept.append(match)
            }
        }
        return kept
    }

    private func rect(for range: NSRange, in line: Line) -> CGRect? {
        let length = (line.text as NSString).length
        guard length > 0, range.location != NSNotFound, range.length > 0 else { return nil }
        let start = Double(range.location) / Double(length)
        let end = Double(range.location + range.length) / Double(length)
        return CGRect(
            x: line.rect.minX + line.rect.width * start,
            y: line.rect.minY,
            width: line.rect.width * (end - start),
            height: line.rect.height
        )
    }

    private func luhnValid(_ digits: String) -> Bool {
        let values = digits.compactMap { $0.wholeNumberValue }
        guard values.count >= 13, values.count <= 19 else { return false }
        var sum = 0
        for (index, digit) in values.reversed().enumerated() {
            if index.isMultiple(of: 2) {
                sum += digit
            } else {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            }
        }
        return sum % 10 == 0
    }
}
