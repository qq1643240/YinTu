# Redacto — 图片隐私打码（净室重写）

对 DAMA 功能对标的**净室重写**：不包含原应用的任何代码、素材、文案与配置。
全部实现基于 Apple 公开框架，零第三方依赖、零网络请求、零遥测。

## 当前状态

| 里程碑 | 内容 | 状态 |
|---|---|---|
| M1 | 工程骨架、文档模型（撤销/重做）、四种导入入口（相册/文件/剪贴板/示例图） | ✅ |
| M2 | 编辑画布（缩放/平移/框选）、色块·马赛克·模糊·马克笔、参数面板、选中/删除、导出（去 EXIF） | ✅ |
| M3 | 检测引擎：Vision OCR/二维码/人脸 + NSDataDetector + NL 姓名，自动打码 | ⏳ |
| M4 | 长按挑词、隐藏文字、表情遮挡、装饰工具、水印工具 | ⏳ |
| M5 | 导出完整化（格式/原尺寸/分享并删除原图） | 🚧 基础版已含 |
| M6 | 照片编辑扩展 + 分享面板扩展 | ⏳ |
| M7 | 设置页 / onboarding / Spotlight / 多语言 | ⏳ |

## 在 Mac 上构建

需要 Xcode 15+ 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
brew install xcodegen
cd redacto
xcodegen          # 生成 Redacto.xcodeproj（目录已被 .gitignore 排除）
open Redacto.xcodeproj
```

选一个 iOS 17+ 模拟器直接 Cmd+R。真机调试需在 Signing & Capabilities 里换成你自己的 Team。

## 架构速览

```
Sources/
  App/         RedactoApp · RootView（导入入口）
  Model/       MaskBlock（块+参数） · RedactDocument（撤销/重做）
  Rendering/   BlockRenderer —— CoreImage 管线，预览与导出共用
  Detection/   Detector 协议（M3 落地实现）
  Editor/      CanvasGestureView（UIKit 手势宿主） · EditorViewModel · EditorView · ToolPanel
  Export/      ExportView + EXIF 剥离
  Support/     ImageCoder · SampleImageGenerator
```

**坐标约定**：`MaskBlock.rect` 是归一化（0…1）、左上原点、y 向下；
`BlockRenderer` 内部翻转到 CoreImage 的左下原点。块内所有尺寸参数（马赛克大小、模糊半径）
按「图像宽度的比例」存储，因此预览（≤1600px 降采样）与全分辨率导出结果一致。

**手势**：单指拖拽 = 框选打码；双指捏合 = 缩放；双指拖动 = 平移（仅放大后）；
双指轻点 = 复位视图；单击 = 选中/取消选中遮盖块。

## 隐私承诺（与实现一致）

- 无任何网络权限与网络请求，无第三方 SDK。
- 检测/渲染全部设备端完成。
- 导出时重新编码，自动剥离全部 EXIF（含 GPS）。

## 合规声明

本项目为功能对标学习用途的净室实现：未复制、未反编译引用、未打包原应用的任何资源；
包名、图标、名称均为原创占位，商用前请自行完成商标与素材的原创化。
