import Foundation
import SwiftData
import SwiftUI

@main
struct ChopChopApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var composer = GeneratePlanViewModel(
        service: BackendPlanningService()
    )

    private let container: ModelContainer = Self.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .environmentObject(composer)
        }
        .modelContainer(container)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            PlannerTask.self,
            PlannerStep.self,
        ])

        let storeURL = persistentStoreURL()
        let configuration = ModelConfiguration(
            "ChopChop",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // During development we changed the SwiftData models several times.
            // If an older on-device store becomes incompatible, recreate it so the app can still boot.
            removePersistentStoreArtifacts(at: storeURL)

            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to create ModelContainer after resetting the local store: \(error)")
            }
        }
    }

    private static func persistentStoreURL() -> URL {
        let applicationSupport = URL.applicationSupportDirectory
        let directory = applicationSupport.appending(path: "ChopChop", directoryHint: .isDirectory)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            fatalError("Failed to create Application Support directory: \(error)")
        }

        return directory.appending(path: "ChopChop.store")
    }

    private static func removePersistentStoreArtifacts(at storeURL: URL) {
        let fileManager = FileManager.default
        let candidateURLs = [
            storeURL,
            storeURL.appendingPathExtension("sqlite"),
            storeURL.appendingPathExtension("sqlite-shm"),
            storeURL.appendingPathExtension("sqlite-wal"),
            storeURL.appendingPathExtension("store-shm"),
            storeURL.appendingPathExtension("store-wal"),
        ]

        for candidateURL in candidateURLs {
            if fileManager.fileExists(atPath: candidateURL.path()) {
                try? fileManager.removeItem(at: candidateURL)
            }
        }
    }
}
