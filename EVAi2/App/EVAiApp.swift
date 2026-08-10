import SwiftUI
import SwiftData

@main
struct EVAiApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase

    let sharedModelContainer: ModelContainer

    init() {
        _ = NetworkMonitor.shared
        BackgroundTaskManager.registerTasks()

        if let container = try? ModelContainerFactory.make() {
            sharedModelContainer = container
            DataSeedingService.seedIfNeeded(modelContext: container.mainContext)
            _ = UserProfileService.ensureProfile(in: container.mainContext)
        } else if let recovered = CrashRecoveryService.handleContainerFailure(
            NSError(domain: "EVAi", code: 1)
        ) {
            sharedModelContainer = recovered
            _ = UserProfileService.ensureProfile(in: recovered.mainContext)
        } else if let fallback = try? ModelContainerFactory.makeInMemoryContainer() {
            sharedModelContainer = fallback
            ErrorLogger.log("Using in-memory fallback container", category: .database)
        } else {
            fatalError("Unable to initialize any SwiftData container.")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                coordinator: coordinator,
                themeManager: themeManager
            )
            .onAppear {
                ImageStorageManager.prepareStorageIfNeeded()
                WidgetDataStore.ensureSnapshotExists()
                UserProfileService.validateStoredAssets(in: sharedModelContainer.mainContext)
                _ = UserProfileService.ensureProfile(in: sharedModelContainer.mainContext)
                BackgroundTaskManager.scheduleRefreshTask()
                Task {
                    await CrashRecoveryService.resumeInterruptedExtraction(
                        context: sharedModelContainer.mainContext
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                ImageCacheService.shared.handleMemoryWarning()
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                BackgroundTaskManager.scheduleProcessingTask()
            }
        }
    }
}
