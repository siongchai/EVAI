import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddCarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.createdAt, order: .reverse) private var cars: [Car]

    @State private var viewModel = CarManagementViewModel()
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.md) {
                CarFormFields(
                    viewModel: viewModel,
                    photoPickerItems: $photoPickerItems,
                    onTakePhoto: { showCamera = true }
                )
                .glassCard()

                GradientButton(title: "Add Car", iconName: "car.fill") {
                    saveAndDismiss()
                }
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Add Car")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoPickerItems) { _, items in
            Task {
                let importedAny = await PhotoImportService.importSequentially(from: items) { data in
                    viewModel.setPhoto(from: data)
                }
                if !importedAny, !items.isEmpty {
                    viewModel.errorMessage = "Unable to load the selected photo."
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
            viewModel.errorMessage = "Unable to save the captured photo."
            return
        }
        viewModel.setPhoto(from: data)
        viewModel.errorMessage = nil
    }

    private func saveAndDismiss() {
        do {
            try viewModel.save(using: modelContext, existingCars: cars)
            dismiss()
        } catch {
            // Validation errors are shown in the form.
        }
    }
}

#Preview {
    NavigationStack {
        AddCarView()
    }
    .modelContainer(for: Car.self, inMemory: true)
    .environment(ThemeManager())
    .applyTheme(ThemeManager())
}
