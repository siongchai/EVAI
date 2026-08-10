import SwiftUI

enum ThemeAssetManager {
    static func splashBackgroundName(for colorScheme: ColorScheme) -> String {
        colorScheme == .dark ? "splash_dark_background" : "splash_light_background"
    }
}
