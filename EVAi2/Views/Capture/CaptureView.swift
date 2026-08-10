import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import SwiftData
import UIKit

struct CaptureView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = CaptureViewModel()
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPDFImporter = false

    private var isPad: Bool { DeviceType.isPad || horizontalSizeClass == .regular }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .capture:
                captureScreen
            case .processing:
                AIProcessingView(viewModel: viewModel)
            case .review:
                ReviewConfirmView(viewModel: viewModel)
            case .viewingSources:
                NavigationStack {
                    SourceImagesView(viewModel: viewModel)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.phase)
        .alert("Capture Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Session Saved", isPresented: $viewModel.didSaveSession) {
            Button("OK", role: .cancel) {
                viewModel.acknowledgeSavedSession()
            }
        } message: {
            Text("Your charging session has been saved successfully.")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            viewModel.handleMemoryWarning()
        }
    }

    private var captureScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                header

                if isPad {
                    iPadDropZone
                }

                imageGrid
                tipsSection
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            analyzeButtonBar
        }
        .sheet(isPresented: $viewModel.isShowingCamera) {
            CameraPicker { image in
                viewModel.capturePhoto(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoPickerItems) { _, items in
            Task {
                let importedAny = await PhotoImportService.importSequentially(from: items) { data in
                    viewModel.importImageData([data])
                }
                if !importedAny, !items.isEmpty {
                    viewModel.errorMessage = "Unable to load the selected files. Try a different image or PDF format."
                    viewModel.showError = true
                }
                photoPickerItems = []
            }
        }
        .fileImporter(
            isPresented: $showPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.importPDFReceipt(from: url)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
                viewModel.showError = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xs) {
            HStack {
                Text("AI Capture")
                    .font(EVAiTypography.title2)
                    .foregroundStyle(colors.primaryText)

                Spacer()

                Button {} label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(colors.secondaryText)
                }
                .buttonStyle(.plain)
            }

            Text("Upload at least 3 photos or receipt files from your charging session.")
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.secondaryText)
        }
        .padding(.top, EVAiSpacing.sm)
    }

    private var iPadDropZone: some View {
        VStack(spacing: EVAiSpacing.md) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.primaryBlue)
                .symbolRenderingMode(.hierarchical)

            Text("Drag & Drop Photos or PDFs Here")
                .font(EVAiTypography.headline)
                .foregroundStyle(colors.primaryText)

            Text("Drop charging photos or receipt PDFs directly into EVAi")
                .font(EVAiTypography.footnote)
                .foregroundStyle(colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EVAiSpacing.xxxl)
        .background {
            RoundedRectangle(cornerRadius: EVAiSpacing.cardRadius, style: .continuous)
                .strokeBorder(
                    viewModel.isDropTargeted ? Color.primaryBlue : colors.cardBorder,
                    style: StrokeStyle(lineWidth: viewModel.isDropTargeted ? 2 : 1, dash: [8, 6])
                )
                .background {
                    RoundedRectangle(cornerRadius: EVAiSpacing.cardRadius, style: .continuous)
                        .fill(viewModel.isDropTargeted ? Color.primaryBlue.opacity(0.08) : colors.cardBackground)
                }
        }
        .dropDestination(for: URL.self) { urls, _ in
            var importedAny = false
            for url in urls {
                if url.pathExtension.lowercased() == "pdf" {
                    viewModel.importPDFReceipt(from: url)
                    importedAny = true
                } else if let data = try? Data(contentsOf: url) {
                    viewModel.importImageData([data])
                    importedAny = true
                }
            }
            return importedAny
        } isTargeted: { targeted in
            viewModel.isDropTargeted = targeted
        }
    }

    private var imageGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: EVAiSpacing.sm),
            GridItem(.flexible(), spacing: EVAiSpacing.sm)
        ]

        return LazyVGrid(columns: columns, spacing: EVAiSpacing.sm) {
            ForEach(Array(viewModel.images.enumerated()), id: \.element.id) { index, item in
                CaptureImageCell(item: item, imageNumber: index + 1) {
                    viewModel.removeImage(item)
                }
            }

            addImageCell
        }
    }

    private var addImageCell: some View {
        VStack(spacing: EVAiSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: ImageProcessor.maxCaptureImages,
                    matching: .images
                ) {
                    VStack(spacing: EVAiSpacing.sm) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(Color.primaryBlue)

                        Text("Add Photos")
                            .font(EVAiTypography.caption)
                            .foregroundStyle(colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 112)
                    .background {
                        RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                            .strokeBorder(colors.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                            .background {
                                RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                                    .fill(colors.cardBackground)
                            }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.isShowingCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.primaryBlue, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(EVAiSpacing.sm)
            }

            Button {
                showPDFImporter = true
            } label: {
                HStack(spacing: EVAiSpacing.xs) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 16, weight: .medium))
                    Text("Upload Receipt PDF")
                        .font(EVAiTypography.caption)
                }
                .foregroundStyle(Color.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EVAiSpacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                        .strokeBorder(Color.primaryBlue.opacity(0.35), lineWidth: 1)
                        .background {
                            RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                                .fill(Color.primaryBlue.opacity(0.08))
                        }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var tipsSection: some View {
        Text("Tips: Include dashboard, charger screen, app summary, receipt photos, or a receipt PDF.")
            .font(EVAiTypography.footnote)
            .foregroundStyle(colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var analyzeButtonBar: some View {
        VStack(spacing: EVAiSpacing.sm) {
            if viewModel.imagesNeededForAnalysis > 0 {
                Text("Add \(viewModel.imagesNeededForAnalysis) more file\(viewModel.imagesNeededForAnalysis == 1 ? "" : "s") to analyze.")
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let statusMessage = AIConfiguration.statusMessage {
                Text(statusMessage)
                    .font(EVAiTypography.caption2)
                    .foregroundStyle(colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            GradientButton(
                title: "Analyze Charging Session",
                iconName: "sparkles",
                isEnabled: viewModel.canAnalyze
            ) {
                Task { await viewModel.analyzeSession(using: modelContext) }
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.top, EVAiSpacing.sm)
            .padding(.bottom, EVAiSpacing.tabBarHeight)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(colors.tabBarBackground.opacity(0.95))
        }
    }
}

private struct CaptureImageCell: View {
    @Environment(\.themeColors) private var colors

    let item: CaptureImageItem
    let imageNumber: Int
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: EVAiSpacing.xs) {
                Image(uiImage: item.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 112)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: EVAiSpacing.xxs) {
                    if item.category == .receipt {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                    }
                    Text("\(item.category.shortTitle) \(imageNumber)")
                        .font(EVAiTypography.caption2)
                        .foregroundStyle(colors.secondaryText)
                }
                .padding(.horizontal, EVAiSpacing.xxs)
            }
            .padding(EVAiSpacing.sm)
            .background {
                RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                    .fill(colors.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                            .strokeBorder(colors.cardBorder, lineWidth: 0.5)
                    }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(EVAiSpacing.sm)
        }
    }
}

struct SourceImagesView: View {
    @Environment(\.themeColors) private var colors
    @Bindable var viewModel: CaptureViewModel

    private let columns = [
        GridItem(.flexible(), spacing: EVAiSpacing.sm),
        GridItem(.flexible(), spacing: EVAiSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: EVAiSpacing.sm) {
                ForEach(Array(viewModel.images.enumerated()), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: EVAiSpacing.xs) {
                        Image(uiImage: item.thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack(spacing: EVAiSpacing.xxs) {
                            if item.category == .receipt {
                                Image(systemName: "doc.richtext.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.primaryBlue)
                            }
                            Text("\(item.category.shortTitle) \(index + 1)")
                                .font(EVAiTypography.caption)
                                .foregroundStyle(colors.secondaryText)
                        }
                    }
                    .padding(EVAiSpacing.sm)
                    .glassCard(padding: EVAiSpacing.sm)
                }
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .navigationTitle("Source Files")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    viewModel.dismissSourceImages()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CaptureView()
    }
    .modelContainer(for: ChargingSession.self, inMemory: true)
    .environment(ThemeManager())
    .applyTheme(ThemeManager())
}
