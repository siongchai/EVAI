import SwiftUI

struct AboutView: View {
    @Environment(\.themeColors) private var colors

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                VStack(spacing: EVAiSpacing.lg) {
                    Image(systemName: "bolt.car.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(EVAiGradients.brand)
                        .frame(width: 88, height: 88)
                        .background(Color.primaryBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(spacing: EVAiSpacing.xs) {
                        Text(AppConstants.appName)
                            .font(EVAiTypography.title2)
                            .foregroundStyle(colors.primaryText)

                        Text(AppConstants.tagline)
                            .font(EVAiTypography.subheadline)
                            .foregroundStyle(colors.secondaryText)
                            .multilineTextAlignment(.center)

                        Text("Version \(appVersion)")
                            .font(EVAiTypography.caption)
                            .foregroundStyle(colors.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, EVAiSpacing.lg)

                VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                    aboutRow(title: "Built for", value: "Singapore EV drivers")
                    aboutRow(title: "Features", value: "AI receipt capture, analytics, Excel import/export")
                    aboutRow(title: "Privacy", value: "Charging data stays on your device")
                }
                .glassCard()
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aboutRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            Text(title)
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)
            Text(value)
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
