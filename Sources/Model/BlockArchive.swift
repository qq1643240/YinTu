import Foundation
import Photos

/// 遮盖块列表 ↔ PHAdjustmentData 载荷的编解码。
/// 照片编辑扩展把它存进 adjustmentData，重新进入编辑时原样还原块。
enum BlockArchive {
    static let formatIdentifier = "com.yintu.app"
    static let formatVersion = "1"

    static func encode(_ blocks: [MaskBlock]) -> Data? {
        try? JSONEncoder().encode(blocks)
    }

    static func decode(_ data: Data) -> [MaskBlock]? {
        try? JSONDecoder().decode([MaskBlock].self, from: data)
    }

    static func isOurs(_ adjustmentData: PHAdjustmentData) -> Bool {
        adjustmentData.formatIdentifier == formatIdentifier && adjustmentData.formatVersion == formatVersion
    }
}
