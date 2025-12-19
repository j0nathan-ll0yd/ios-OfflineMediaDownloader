import CoreData

struct PersistenceController {
  /// Check if running in a test environment
  private static var isTestEnvironment: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
    NSClassFromString("XCTestCase") != nil
  }

  static let shared: PersistenceController = {
    // Use in-memory store for test environments to avoid CoreData issues
    if isTestEnvironment {
      return PersistenceController(inMemory: true)
    }
    return PersistenceController()
  }()

  @MainActor
  static let preview: PersistenceController = {
    let result = PersistenceController(inMemory: true)
    return result
  }()

  let container: NSPersistentContainer

  init(inMemory: Bool = false) {
    container = NSPersistentContainer(name: "OfflineMediaDownloader")
    if inMemory {
      container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    }
    container.loadPersistentStores { storeDescription, error in
      if let error = error as NSError? {
        // In test environments, log but don't crash
        if PersistenceController.isTestEnvironment {
          print("⚠️ CoreData error in test environment: \(error)")
          return
        }
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSOverwriteMergePolicy
  }

  var viewContext: NSManagedObjectContext {
    container.viewContext
  }
}
