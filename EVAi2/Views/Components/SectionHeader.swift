import SwiftUI

struct SectionHeader: View {
    @Environment(\.themeColors) private var colors

    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(EVAiTypography.title3)
                .foregroundStyle(colors.primaryText)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(Color.primaryBlue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
