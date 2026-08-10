import SwiftUI
import UIKit

struct CarAvatarView: View {
    let image: UIImage?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "car.fill")
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(Color.primaryBlue)
            }
        }
        .frame(width: size, height: size)
        .background(Color.primaryBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

extension CarAvatarView {
    init(car: Car, size: CGFloat = 44) {
        self.init(image: car.photoImage, size: size)
    }
}
