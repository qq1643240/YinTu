import SwiftUI

/// 设置页：自动打码开关、OCR 语言优先级、隐私说明、版本信息。
struct SettingsView: View {
    @AppStorage("auto_mask_on_open") private var autoMaskOnOpen = true
    @AppStorage(DetectionLanguageStore.zhKey) private var ocrChinese = true
    @AppStorage(DetectionLanguageStore.enKey) private var ocrEnglish = true
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(L("settings.auto_mask"), isOn: $autoMaskOnOpen)
                } header: {
                    Text(L("settings.redact.section"))
                } footer: {
                    Text(L("settings.auto_mask.footer"))
                }

                Section {
                    Toggle(L("settings.ocr.zh"), isOn: $ocrChinese)
                    Toggle(L("settings.ocr.en"), isOn: $ocrEnglish)
                } header: {
                    Text(L("settings.ocr.section"))
                } footer: {
                    Text(L("settings.ocr.footer"))
                }

                Section {
                    Label(L("settings.privacy.offline"), systemImage: "wifi.slash")
                    Label(L("settings.privacy.no_sdk"), systemImage: "checkmark.shield")
                    Label(L("settings.privacy.exif"), systemImage: "location.slash")
                } header: {
                    Text(L("settings.privacy.section"))
                }

                Section {
                    LabeledContent(L("settings.about.version"), value: appVersion)
                } header: {
                    Text(L("settings.about.section"))
                }
            }
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }
}
