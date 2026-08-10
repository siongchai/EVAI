import SwiftUI

enum EVAiTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    static let metricValue = Font.system(size: 24, weight: .bold, design: .rounded)
    static let metricLabel = Font.system(size: 13, weight: .medium, design: .default)
    static let tabLabel = Font.system(size: 10, weight: .medium, design: .default)
    static let button = Font.system(size: 17, weight: .semibold, design: .rounded)
}

struct EVAiTextStyle: ViewModifier {
    let font: Font
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
    }
}

extension View {
    func evaiTextStyle(_ font: Font, color: Color) -> some View {
        modifier(EVAiTextStyle(font: font, color: color))
    }
}
