import UIKit

enum SampleImageGenerator {
    /// 程序生成一张假聊天卡片风格的示例图（不含任何真实数据），
    /// 供试用与教学，无需打包任何素材。
    static func make() -> UIImage {
        let size = CGSize(width: 1000, height: 700)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            let card = CGRect(x: 60, y: 70, width: 880, height: 540)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: card, cornerRadius: 24).fill()
            UIColor(red: 0.85, green: 0.87, blue: 0.9, alpha: 1).setFill()
            UIRectFill(CGRect(x: 60, y: 168, width: 880, height: 1))

            draw("王小明", at: CGPoint(x: 110, y: 104), size: 30, weight: .semibold, color: .black)
            draw("138-0000-0000", at: CGPoint(x: 110, y: 196), size: 26, color: .darkGray)
            draw("xiaoming@example.com", at: CGPoint(x: 110, y: 256), size: 24, color: .darkGray)
            draw("身份证 110101199001011234", at: CGPoint(x: 110, y: 326), size: 24, color: .darkGray)
            draw("车牌 京A·12345", at: CGPoint(x: 110, y: 396), size: 24, color: .darkGray)
            draw("地址：北京市东城区某某路 1 号", at: CGPoint(x: 110, y: 466), size: 22, color: .gray)
            draw("试用：框选任意区域，试试色块 / 马赛克 / 模糊 / 马克笔", at: CGPoint(x: 110, y: 548), size: 20, color: .lightGray)
        }
    }

    private static func draw(
        _ text: String,
        at point: CGPoint,
        size: CGFloat,
        weight: UIFont.Weight = .regular,
        color: UIColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
        ]
        text.draw(at: point, withAttributes: attributes)
    }
}
