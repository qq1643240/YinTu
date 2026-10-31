import Foundation

/// 检测结果的合并与"自动打码"块生成。
enum DetectionService {
    /// 迭代合并相交矩形（不同敏感类别叠在一起时只留一个块）。
    /// 合并后保留面积较大一方的 label。
    static func merge(_ regions: [DetectedRegion]) -> [DetectedRegion] {
        var items = regions
        var changed = true
        while changed {
            changed = false
            outer: for i in items.indices {
                for j in items.indices where j > i {
                    guard items[i].rect.intersects(items[j].rect) else { continue }
                    let keepFirst = items[i].rect.area >= items[j].rect.area
                    let kept = keepFirst ? items[i] : items[j]
                    items[i] = DetectedRegion(
                        rect: items[i].rect.union(items[j].rect),
                        kind: kept.kind,
                        label: kept.label
                    )
                    items.remove(at: j)
                    changed = true
                    break outer
                }
            }
        }
        return items
    }

    /// 敏感区域 → 遮盖块；跳过与已有块相交的区域，避免重复覆盖。
    static func autoRedactBlocks(
        from sensitive: [DetectedRegion],
        existing: [MaskBlock]
    ) -> [MaskBlock] {
        var blocks: [MaskBlock] = []
        for region in merge(sensitive) {
            let covered = existing.contains { $0.rect.intersects(region.rect) }
            guard !covered else { continue }
            // 四周留边：OCR/人脸框普遍偏紧
            var rect = region.rect.insetBy(
                dx: -max(0.008, region.rect.width * 0.08),
                dy: -max(0.006, region.rect.height * 0.18)
            )
            rect = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard rect.width > 0.004, rect.height > 0.004 else { continue }
            var block = MaskBlock(kind: .colorBlock, rect: rect)
            block.color = .ink
            block.opacity = 1
            blocks.append(block)
        }
        return blocks
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
