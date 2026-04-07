import ComposableArchitecture
@preconcurrency import CoreData

public struct PersistenceController: Sendable {
  /// Check if running in a test environment
  private static var isTestEnvironment: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
      NSClassFromString("XCTestCase") != nil
  }

  public static let shared: PersistenceController = {
    if isTestEnvironment {
      return PersistenceController(inMemory: true)
    }
    return PersistenceController()
  }()

  @MainActor
  public static let preview: PersistenceController = .init(inMemory: true)

  public let container: NSPersistentContainer

  public init(inMemory: Bool = false) {
    container = NSPersistentContainer(name: "OfflineMediaDownloader")
    if inMemory {
      container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    }
    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        if PersistenceController.isTestEnvironment {
          @Dependency(\.logger) var logger
          logger.warning(.storage, "CoreData error in test environment: \(error)")
          return
        }
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSOverwriteMergePolicy
  }

  public var viewContext: NSManagedObjectContext {
    container.viewContext
  }
}
