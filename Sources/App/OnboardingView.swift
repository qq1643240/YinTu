import SwiftUI

/// 首次启动四步引导。
struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0

    private struct Step {
        let icon: String
        let titleKey: String
        let textKey: String
    }

    private let steps: [Step] = [
        Step(icon: "photo.on.rectangle.angled", titleKey: "onboard.import.title", textKey: "onboard.import.text"),
        Step(icon: "wand.and.stars", titleKey: "onboard.detect.title", textKey: "onboard.detect.text"),
        Step(icon: "hand.draw", titleKey: "onboard.edit.title", textKey: "onboard.edit.text"),
        Step(icon: "lock.shield", titleKey: "onboard.privacy.title", textKey: "onboard.privacy.text"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(steps.indices, id: \.self) { index in
                    let step = steps[index]
                    VStack(spacing: 24) {
                        Image(systemName: step.icon)
                            .font(.system(size: 72, weight: .light))
                            .foregroundStyle(.accent)
                        Text(L(step.titleKey))
                            .font(.title2.bold())
                        Text(L(step.textKey))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 48)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < steps.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < steps.count - 1 ? L("onboard.next") : L("onboard.start"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
