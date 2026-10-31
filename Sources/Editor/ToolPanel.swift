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

    var body: some View {
        VStack(spacing: 12) {
            toolRow
            parameterRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 工具行

    private var toolRow: some View {
        HStack(spacing: 10) {
            ForEach(ToolKind.allCases) { tool in
                Button {
                    viewModel.selectTool(tool)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.symbolName)
                            .font(.system(size: 18, weight: .medium))
                            .frame(height: 22)
                        Text(tool.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.activeTool == tool ? Color.accentColor.opacity(0.16) : .clear)
                    )
                    .foregroundStyle(viewModel.activeTool == tool ? Color.accentColor : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 参数行

    @ViewBuilder
    private var parameterRow: some View {
        switch viewModel.activeTool {
        case .colorBlock, .marker:
            HStack(spacing: 10) {
                ForEach(0..<palette.count, id: \.self) { index in
                    Button {
                        viewModel.strokeColor = palette[index]
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
                Spacer()
                opacitySlider
            }
        case .pixelate:
            HStack(spacing: 10) {
                parameterLabel("颗粒")
                Slider(value: pixelSizeBinding, in: 0.005...0.12)
                cornerRadiusSlider
            }
        case .blur:
            HStack(spacing: 10) {
                parameterLabel("强度")
                Slider(value: blurRadiusBinding, in: 0.005...0.06)
                cornerRadiusSlider
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

    // MARK: - 绑定（有选中块→改块，无选中→改默认笔刷）

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
}
