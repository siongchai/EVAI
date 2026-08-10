import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportDataView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.createdAt, order: .reverse) private var cars: [Car]
    @Query(sort: \ChargingSession.startDate, order: .reverse) private var sessions: [ChargingSession]

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var showImportPicker = false
    @State private var isImporting = false
    @State private var importResultMessage = ""
    @State private var showImportResult = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                    Text("Import & Export")
                        .font(EVAiTypography.title3)
                        .foregroundStyle(colors.primaryText)

                    Text("Import charging logs from Excel, or export your sessions for backup and analysis.")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(colors.secondaryText)
                }

                VStack(spacing: EVAiSpacing.sm) {
                    OutlineButton(title: "Import Excel") {
                        showImportPicker = true
                    }

                    OutlineButton(title: "Export Excel") {
                        shareExport(format: .xlsx)
                    }

                    OutlineButton(title: "Export JSON") {
                        shareExport(format: .json)
                    }

                    OutlineButton(title: "Export PDF") {
                        shareExport(format: .pdf)
                    }
                }
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.spreadsheet, xlsxContentType].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage)
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("Importing sessions…")
                        .padding(EVAiSpacing.lg)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var xlsxContentType: UTType? {
        UTType(filenameExtension: "xlsx")
    }

    private func shareExport(format: ExportFormat) {
        let data = ExportService.exportData(format: format, sessions: sessions)
        let fileName = "EVAi_Sessions_\(ExportService.fileNameDateStamp()).\(format.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            shareItems = [url]
            showShareSheet = true
        } catch {
            shareItems = [data]
            showShareSheet = true
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await importExcel(from: url) }
        case .failure(let error):
            importResultMessage = error.localizedDescription
            showImportResult = true
        }
    }

    @MainActor
    private func importExcel(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            _ = try? await LTAChargerCatalogSyncService.refreshCatalogIfConfigured()
            let data = try Data(contentsOf: url)
            let carModel = cars.first(where: \.isPrimary)?.displayName ?? "Unknown Car"
            let result = try ExcelImportService.importSessions(
                from: data,
                carModel: carModel,
                existingSessions: sessions
            )

            for session in result.sessions {
                modelContext.insert(session)
            }
            try modelContext.save()

            let allSessions = (try? modelContext.fetch(FetchDescriptor<ChargingSession>())) ?? sessions
            WidgetDataStore.sync(from: allSessions)
            AnalyticsCacheService.save(
                AnalyticsCacheService.rebuildSummary(from: allSessions, month: .now.startOfMonth)
            )

            var message = "Imported \(result.importedCount) session\(result.importedCount == 1 ? "" : "s")."
            if result.updatedCount > 0 {
                message += " Updated \(result.updatedCount) existing session\(result.updatedCount == 1 ? "" : "s")."
            }
            if result.skippedInvalid > 0 {
                message += " Skipped \(result.skippedInvalid) invalid row\(result.skippedInvalid == 1 ? "" : "s")."
            }
            importResultMessage = message
            showImportResult = true
        } catch {
            importResultMessage = error.localizedDescription
            showImportResult = true
        }
    }
}
