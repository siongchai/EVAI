import SwiftUI
import PhotosUI
import UIKit

struct AccountFormFields: View {
    @Environment(\.themeColors) private var colors
    @Bindable var viewModel: ProfileAccountViewModel
    @Binding var photoPickerItems: [PhotosPickerItem]

    let onTakePhoto: () -> Void

    private var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            photoSection

            VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                SectionHeader(title: "Personal Information")

                SessionFormField(
                    label: "Name",
                    text: $viewModel.fullName,
                    keyboard: .default
                )

                SessionFormField(
                    label: "Email",
                    text: $viewModel.email,
                    keyboard: .emailAddress
                )
            }

            VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                SectionHeader(title: "Sign In")

                Text("Login and password options will be available here in a future update.")
                    .font(EVAiTypography.footnote)
                    .foregroundStyle(colors.secondaryText)
            }
        }
    }

    private var photoSection: some View {
        VStack(spacing: EVAiSpacing.sm) {
            ProfileAvatarView(
                name: viewModel.fullName.isEmpty ? AppConstants.defaultUserName : viewModel.fullName,
                image: viewModel.photoPreview,
                size: 96
            )

            HStack(spacing: EVAiSpacing.sm) {
                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: 1,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text(viewModel.photoPreview == nil ? "Upload Photo" : "Change Photo")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(Color.primaryBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, EVAiSpacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primaryBlue.opacity(0.35), lineWidth: 1)
                        }
                }
                .photosPickerStyle(.presentation)
                .buttonStyle(.plain)

                if canUseCamera {
                    Button(action: onTakePhoto) {
                        Text("Take Photo")
                            .font(EVAiTypography.subheadline)
                            .foregroundStyle(Color.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, EVAiSpacing.sm)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.primaryBlue.opacity(0.35), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.photoPreview != nil {
                Button("Remove Photo") {
                    viewModel.removePhoto()
                }
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EVAiSpacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colors.cardBorder.opacity(0.25))
                }
                .buttonStyle(.plain)
            }

            Text("Choose from your photo library or take a new photo. Tap Save Changes to keep your profile photo.")
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
