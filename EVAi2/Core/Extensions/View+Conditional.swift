import SwiftUI
import UIKit

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct DeviceType {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
