import SwiftUI

struct HelpSupportView: View {
    @Environment(\.themeColors) private var colors

    private let faqItems: [(question: String, answer: String)] = [
        (
            "How do I log a charging session?",
            "Tap Capture, upload your charging app screenshots or a PDF receipt, then review and save the extracted session."
        ),
        (
            "Can I import my existing Excel log?",
            "Yes. Open Profile → Export Data → Import Excel to bring in sessions from your spreadsheet."
        ),
        (
            "Where is my data stored?",
            "All charging sessions and settings are stored locally on your device. Cloud AI keys are kept in the device Keychain."
        ),
        (
            "Why is idle time separate from total session?",
            "Total session includes idle time after charging stops. Active charging is used to calculate when power delivery ended."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                    Text("FAQ")
                        .font(EVAiTypography.title3)
                        .foregroundStyle(colors.primaryText)

                    Text("Quick answers to common questions about EVAi.")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(colors.secondaryText)
                }

                VStack(spacing: EVAiSpacing.sm) {
                    ForEach(Array(faqItems.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: EVAiSpacing.xs) {
                            Text(item.question)
                                .font(EVAiTypography.headline)
                                .foregroundStyle(colors.primaryText)

                            Text(item.answer)
                                .font(EVAiTypography.subheadline)
                                .foregroundStyle(colors.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                    }
                }

                VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                    Text("Contact")
                        .font(EVAiTypography.title3)
                        .foregroundStyle(colors.primaryText)

                    Link(destination: URL(string: "mailto:support@evai.app")!) {
                        HStack(spacing: EVAiSpacing.md) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(Color.primaryBlue)
                            Text("support@evai.app")
                                .font(EVAiTypography.subheadline)
                                .foregroundStyle(Color.primaryBlue)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(colors.secondaryText)
                        }
                        .glassCard(padding: EVAiSpacing.md)
                    }
                }
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}
