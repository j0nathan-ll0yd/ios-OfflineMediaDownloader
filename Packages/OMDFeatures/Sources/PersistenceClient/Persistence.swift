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

  public static func makeTestContainer() -> NSPersistentContainer {
    let container = NSPersistentContainer(name: "OfflineMediaDownloader")
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    description.url = URL(string: "memory://\(UUID().uuidString)")
    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        @Dependency(\.logger) var logger
        logger.warning(.storage, "CoreData test container error: \(error)")
      }
    }
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSOverwriteMergePolicy
    return container
  }

  public let container: NSPersistentContainer

  public init(container: NSPersistentContainer) {
    self.container = container
  }

  public init(inMemory: Bool = false) {
    if inMemory {
      container = PersistenceController.makeTestContainer()
    } else {
      container = NSPersistentContainer(name: "OfflineMediaDownloader")
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
  }

  public var viewContext: NSManagedObjectContext {
    container.viewContext
  }
}
