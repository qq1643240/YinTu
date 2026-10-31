# 隐图 YinTu — 图片隐私打码（净室重写）

对 DAMA 功能对标的**净室重写**：不包含原应用的任何代码、素材、文案与配置。
全部实现基于 Apple 公开框架，零第三方依赖、零网络请求、零遥测。

App 名称：**隐图**（YinTu） · Bundle ID：`com.yintu.app`（扩展 `com.yintu.app.PhotoEditor` / `com.yintu.app.Share`）

## 当前状态

| 里程碑 | 内容 | 状态 |
|---|---|---|
| M1 | 工程骨架、文档模型（撤销/重做）、四种导入入口（相册/文件/剪贴板/示例图） | ✅ |
| M2 | 编辑画布（缩放/平移/框选）、色块·马赛克·模糊·马克笔、参数面板、选中/删除、导出（去 EXIF） | ✅ |
| M3 | 检测引擎：Vision OCR/二维码/人脸 + NSDataDetector + NL 姓名，自动打码 | ✅ |
| M4 | 长按挑词、隐藏文字、表情遮挡、装饰工具（城市灯光/墨迹/噪点/彩虹条/彩虹格）、水印工具、刷子 | ✅ |
| M5 | 导出完整化（JPEG/PNG + 质量滑杆、全分辨率渲染、分享并删除原图） | ✅ |
| M6 | 照片编辑扩展（Photos 内直接打码，块随 adjustmentData 往返）+ 分享面板扩展（存入相册） | ✅ |
| M7 | 设置页 / 首启引导 / Spotlight 快捷指令 / 双语（en+zh-Hans，shell 层） | ✅ |

## 构建

需要 Xcode 15+ 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
brew install xcodegen
xcodegen          # 生成 YinTu.xcodeproj（目录已被 .gitignore 排除）
open YinTu.xcodeproj
```

选一个 iOS 17+ 模拟器直接 Cmd+R。真机调试需在 Signing & Capabilities 里换成你自己的 Team。

### CI 自动出包

推送即触发 GitHub Actions（`.github/workflows/ios.yml`，macOS runner）：
xcodegen → `xcodebuild` 无签名真机构建（`CODE_SIGNING_ALLOWED=NO`）→ 打包 `YinTu-unsigned.ipa` 上传为 Artifact。
IPA 未签名，安装到真机请用 AltStore / Sideloadly / TrollStore 或 Xcode 重签。

## 架构速览

```
Sources/
  App/         YinTuApp · RootView（导入入口） · Intents（"打码最新的图片"快捷指令） · SettingsView · OnboardingView
  Model/       MaskBlock（块+参数） · RedactDocument（撤销/重做） · BlockArchive（扩展往返编码）
  Rendering/   BlockRenderer（CoreImage 管线+TextTiler 平铺） —— 预览与导出共用
  Detection/   VisionAnalyzer（单通道 OCR/条码/人脸） · PatternDetector（电话/邮箱/证件号/车牌/卡号/姓名） · DetectionService（合并+自动打码）
  Editor/      CanvasGestureView（UIKit 手势宿主） · EditorViewModel · EditorView（chromeless 可嵌入扩展） · ToolPanel
  Export/      ExportView + EXIF 剥离
  Support/     ImageCoder · SampleImageGenerator · DetectionLanguageStore · Localization(L)
Resources/
  Assets.xcassets · en.lproj + zh-Hans.lproj（Localizable.strings：主界面/设置/引导；编辑器内文案暂为中文，键已铺好可扩展）
Extensions/
  PhotoEditor/ Photos 编辑扩展：主 App 编辑器整体嵌入，块列表经 PHAdjustmentData 往返
  ActionShare/ 分享面板扩展：把分享来的图片存入相册
```

**坐标约定**：`MaskBlock.rect` 是归一化（0…1）、左上原点、y 向下；
`BlockRenderer` 内部翻转到 CoreImage 的左下原点。块内所有尺寸参数（马赛克大小、模糊半径）
按「图像宽度的比例」存储，因此预览（≤1600px 降采样）与全分辨率导出结果一致。

**手势**：单指拖拽 = 框选打码（刷子工具=自由涂抹）；双指捏合 = 缩放；双指拖动 = 平移（仅放大后）；
双指轻点 = 复位视图；单击 = 选中/取消选中遮盖块；长按 = 直接打码命中的检测词。

## 隐私承诺（与实现一致）

- 无任何网络权限与网络请求，无第三方 SDK。
- 检测/渲染全部设备端完成。
- 导出时重新编码，自动剥离全部 EXIF（含 GPS）。

## 合规声明

本项目为功能对标学习用途的净室实现：未复制、未反编译引用、未打包原应用的任何资源；
包名、图标、名称均为原创占位，商用前请自行完成商标与素材的原创化。
