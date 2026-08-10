import BackgroundTasks
import Foundation
import SwiftData

enum BackgroundTaskManager {
    static let refreshIdentifier = "sg.tsc.EVAi2.background.refresh"
    static let processingIdentifier = "sg.tsc.EVAi2.background.processing"

    static func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshIdentifier,
            using: nil
        ) { task in
            handleRefresh(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: processingIdentifier,
            using: nil
        ) { task in
            handleProcessing(task: task as! BGProcessingTask)
        }
    }

    static func scheduleRefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: processingIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefreshTask()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            do {
                let container = try ModelContainerFactory.make()
                let context = container.mainContext
                _ = await ExtractionQueueService.processPending(context: context)
                ExtractionQueueService.purgeCompleted(context: context)
                task.setTaskCompleted(success: true)
            } catch {
                ErrorLogger.log("Background refresh failed", category: .background, error: error)
                task.setTaskCompleted(success: false)
            }
        }
    }

    private static func handleProcessing(task: BGProcessingTask) {
        scheduleProcessingTask()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            do {
                cleanTemporaryFiles()
                ImageStorageManager.compressStoredImages()

                let container = try ModelContainerFactory.make()
                let context = container.mainContext
                let protectedIDs = ImageStorageManager.protectedImageIDs(from: context)
                ImageStorageManager.deleteOrphans(validIDs: protectedIDs)

                let sessions = (try? context.fetch(FetchDescriptor<ChargingSession>())) ?? []
                let month = Date.now.startOfMonth
                let snapshot = AnalyticsCacheService.rebuildSummary(from: sessions, month: month)
                AnalyticsCacheService.save(snapshot)
                WidgetDataStore.sync(from: sessions)

                _ = await ExtractionQueueService.processPending(context: context)
                task.setTaskCompleted(success: true)
            } catch {
                ErrorLogger.log("Background processing failed", category: .background, error: error)
                task.setTaskCompleted(success: false)
            }
        }
    }

    static func cleanTemporaryFiles() {
        let temp = FileManager.default.temporaryDirectory
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: temp,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for url in urls where url.lastPathComponent.hasPrefix("EVAi") || url.pathExtension == "csv" || url.pathExtension == "pdf" {
            if let created = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
               created < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
