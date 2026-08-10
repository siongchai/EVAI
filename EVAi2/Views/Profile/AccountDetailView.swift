import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AccountDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var profile: UserProfile

    @State private var viewModel = ProfileAccountViewModel()
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.md) {
                AccountFormFields(
                    viewModel: viewModel,
                    photoPickerItems: $photoPickerItems,
                    onTakePhoto: { showCamera = true }
                )
                .glassCard()

                if let saveMessage = viewModel.saveMessage {
                    Text(saveMessage)
                        .font(EVAiTypography.caption)
                        .foregroundStyle(Color(hex: 0x34C759))
                }

                if let saveError = viewModel.saveError {
                    Text(saveError)
                        .font(EVAiTypography.caption)
                        .foregroundStyle(Color(hex: 0xFF3B30))
                }

                GradientButton(title: "Save Changes", iconName: "checkmark") {
                    saveAndDismiss()
                }
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.bind(profile: profile)
        }
        .onChange(of: photoPickerItems) { _, items in
            Task {
                let importedAny = await PhotoImportService.importSequentially(from: items) { data in
                    viewModel.setPhoto(from: data)
                }
                if !importedAny, !items.isEmpty {
                    viewModel.saveError = "Unable to load the selected photo."
                } else {
                    viewModel.saveError = nil
                }
                photoPickerItems = []
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                importCapturedPhoto(image)
            }
            .ignoresSafeArea()
        }
    }

    private func importCapturedPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            viewModel.saveError = "Unable to save the captured photo."
            return
        }
        viewModel.setPhoto(from: data)
        viewModel.saveError = nil
    }

    private func saveAndDismiss() {
        if viewModel.save(to: profile, using: modelContext) {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        AccountDetailView(profile: UserProfile(fullName: "Alex", email: "alex@example.com"))
    }
    .modelContainer(for: UserProfile.self, inMemory: true)
    .environment(ThemeManager())
    .applyTheme(ThemeManager())
}
