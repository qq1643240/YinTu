import SwiftUI

extension RGBA {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    init(_ color: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).getRed(&red, &green, &blue, &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}

struct ToolPanel: View {
    let viewModel: EditorViewModel

    private let palette: [RGBA] = [
        RGBA(red: 0.12, green: 0.12, blue: 0.12, alpha: 1),
        RGBA(red: 1, green: 1, blue: 1, alpha: 1),
        RGBA(red: 0.95, green: 0.2, blue: 0.2, alpha: 1),
        RGBA(red: 0.1, green: 0.55, blue: 1, alpha: 1),
        RGBA(red: 0.2, green: 0.75, blue: 0.35, alpha: 1),
        RGBA(red: 1, green: 0.85, blue: 0.1, alpha: 1),
    ]

    /// 十二工具按用途分两排，宽度才放得下
    private let toolRows: [[ToolKind]] = [
        [.colorBlock, .pixelate, .blur, .marker, .brush, .hideText],
        [.emoji, .watermark, .cityLights, .inkStroke, .noisyColorBlock, .rainbowBelt, .rainbowGrid],
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(toolRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(toolRows[rowIndex], id: \.self) { tool in
                        toolButton(tool)
                    }
                }
            }
            parameterRow
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 工具按钮

    private func toolButton(_ tool: ToolKind) -> some View {
        Button {
            viewModel.selectTool(tool)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tool.symbolName)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)
                Text(tool.title)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(viewModel.activeTool == tool ? Color.accentColor.opacity(0.16) : .clear)
            )
            .foregroundStyle(viewModel.activeTool == tool ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 参数行（按当前工具切换）

    @ViewBuilder
    private var parameterRow: some View {
        switch viewModel.activeTool {
        case .colorBlock, .marker, .inkStroke:
            HStack(spacing: 10) {
                colorSwatches
                Spacer()
                opacitySlider
            }
        case .pixelate, .noisyColorBlock, .rainbowGrid:
            HStack(spacing: 10) {
                parameterLabel("颗粒")
                Slider(value: pixelSizeBinding, in: 0.005...0.12)
                cornerRadiusSlider
            }
        case .blur, .cityLights:
            HStack(spacing: 10) {
                parameterLabel("强度")
                Slider(value: blurRadiusBinding, in: 0.005...0.06)
                cornerRadiusSlider
            }
        case .brush:
            HStack(spacing: 10) {
                colorSwatches
                Spacer()
                parameterLabel("粗细")
                Slider(value: pixelSizeBinding, in: 0.008...0.06)
                    .frame(maxWidth: 120)
            }
        case .hideText:
            HStack(spacing: 8) {
                parameterLabel("吸取目标背景色，盖住文字即可")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                cornerRadiusSlider
            }
        case .emoji:
            HStack(spacing: 8) {
                parameterLabel("表情")
                emojiPicker
                Spacer()
            }
        case .watermark:
            watermarkControls
        case .rainbowBelt:
            HStack(spacing: 8) {
                parameterLabel("斜向彩虹条：拖拽框选即铺满整块")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                cornerRadiusSlider
            }
        }
    }

    private var colorSwatches: some View {
        HStack(spacing: 10) {
            ForEach(0..<palette.count, id: \.self) { index in
                Button {
                    viewModel.strokeColor = palette[index]
                    viewModel.modifySelected { $0.color = palette[index] }
                } label: {
                    Circle()
                        .fill(palette[index].swiftUIColor)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().strokeBorder(
                                viewModel.strokeColor == palette[index] ? Color.accentColor : .clear,
                                lineWidth: 2
                            )
                            .padding(-3)
                        )
                }
                .buttonStyle(.plain)
            }
            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 30)
        }
    }

    /// 表情选择：一排常用 + 少量候选，点选即设
    private var emojiPicker: some View {
        Menu {
            ForEach(["😎", "🥰", "🤣", "🎉", "⭐️", "🍀", "🐱", "🐶", "🌈", "🍕", "🚀", "🌙"], id: \.self) { item in
                Button(item) {
                    viewModel.emoji = item
                    viewModel.modifySelected { $0.emoji = item }
                }
            }
        } label: {
            Text(viewModel.emoji)
                .font(.title3)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var watermarkControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                parameterLabel("文字")
                TextField("水印文字", text: textBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Spacer()
            }
            HStack(spacing: 8) {
                parameterLabel("大小")
                Slider(value: watermarkSizeBinding, in: 0.015...0.12)
                parameterLabel("角度")
                Slider(value: watermarkAngleBinding, in: -90...90)
                parameterLabel("行距")
                Slider(value: watermarkLineSpacingBinding, in: 1...4)
            }
        }
    }

    private var opacitySlider: some View {
        HStack(spacing: 6) {
            parameterLabel("不透明")
            Slider(value: opacityBinding, in: 0.1...1)
                .frame(maxWidth: 110)
        }
    }

    private var cornerRadiusSlider: some View {
        HStack(spacing: 6) {
            parameterLabel("圆角")
            Slider(value: cornerRadiusBinding, in: 0...0.5)
                .frame(maxWidth: 110)
        }
    }

    private func parameterLabel(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    // MARK: - 绑定（有选中块→改块，无选中→改下次创建的默认值）

    private var colorBinding: Binding<Color> {
        Binding(
            get: { viewModel.strokeColor.swiftUIColor },
            set: { viewModel.strokeColor = RGBA($0) }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { viewModel.opacity },
            set: { newValue in
                viewModel.opacity = newValue
                viewModel.modifySelected { $0.opacity = newValue }
            }
        )
    }

    private var pixelSizeBinding: Binding<Double> {
        Binding(
            get: { viewModel.pixelSize },
            set: { newValue in
                viewModel.pixelSize = newValue
                viewModel.modifySelected { $0.pixelSize = newValue }
            }
        )
    }

    private var blurRadiusBinding: Binding<Double> {
        Binding(
            get: { viewModel.blurRadius },
            set: { newValue in
                viewModel.blurRadius = newValue
                viewModel.modifySelected { $0.blurRadius = newValue }
            }
        )
    }

    private var cornerRadiusBinding: Binding<Double> {
        Binding(
            get: { viewModel.cornerRadius },
            set: { newValue in
                viewModel.cornerRadius = newValue
                viewModel.modifySelected { $0.cornerRadius = newValue }
            }
        )
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { viewModel.watermarkText },
            set: { newValue in
                viewModel.watermarkText = newValue
                viewModel.modifySelected { $0.watermarkText = newValue }
            }
        )
    }

    private var watermarkSizeBinding: Binding<Double> {
        Binding(
            get: { viewModel.watermarkSize },
            set: { newValue in
                viewModel.watermarkSize = newValue
                viewModel.modifySelected { $0.watermarkSize = newValue }
            }
        )
    }

    private var watermarkAngleBinding: Binding<Double> {
        Binding(
            get: { viewModel.watermarkAngle },
            set: { newValue in
                viewModel.watermarkAngle = newValue
                viewModel.modifySelected { $0.watermarkAngle = newValue }
            }
        )
    }

    private var watermarkLineSpacingBinding: Binding<Double> {
        Binding(
            get: { viewModel.watermarkLineSpacing },
            set: { newValue in
                viewModel.watermarkLineSpacing = newValue
                viewModel.modifySelected { $0.watermarkLineSpacing = newValue }
            }
        )
    }
}
