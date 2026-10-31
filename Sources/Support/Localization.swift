import Foundation

/// 本地化取词：默认中文（zh-Hans 是源语言），en.lproj 有完整覆盖；
/// 编辑器内部工具名暂不参与（见 README「多语言」说明）。
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
