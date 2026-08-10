import SwiftUI
import UIKit

private struct ScreenshotPreventModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isEnabled {
                SecureTextFieldRepresentable()
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct SecureTextFieldRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        let view = field.subviews.first ?? UIView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    func preventScreenshots(_ enabled: Bool = true) -> some View {
        modifier(ScreenshotPreventModifier(isEnabled: enabled))
    }
}
