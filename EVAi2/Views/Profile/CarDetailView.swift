import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct CarDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.createdAt, order: .reverse) private var cars: [Car]

    @Bindable var car: Car

    @State private var viewModel = CarManagementViewModel()
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.md) {
                CarFormFields(
                    viewModel: viewModel,
                    photoPickerItems: $photoPickerItems,
                    onTakePhoto: { showCamera = true }
                )
                .glassCard()

                GradientButton(title: "Save Changes", iconName: "checkmark") {
                    saveAndDismiss()
                }

                if !car.isPrimary {
                    OutlineButton(title: "Set as Default Car") {
                        try? viewModel.setPrimary(car, allCars: cars, using: modelContext)
                    }
                }

                OutlineButton(title: "Delete Car") {
                    showDeleteConfirmation = true
                }
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(car.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.beginEditing(car)
        }
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
        .confirmationDialog(
            "Delete this car?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Car", role: .destructive) {
                deleteAndDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
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

    private func deleteAndDismiss() {
        do {
            try viewModel.delete(car, using: modelContext)
            dismiss()
        } catch {
            viewModel.errorMessage = "Unable to delete this car."
        }
    }
}

#Preview {
    NavigationStack {
        CarDetailView(car: Car(make: "Tesla", modelName: "Model 3", variant: "Long Range"))
    }
    .modelContainer(for: Car.self, inMemory: true)
    .environment(ThemeManager())
    .applyTheme(ThemeManager())
}
