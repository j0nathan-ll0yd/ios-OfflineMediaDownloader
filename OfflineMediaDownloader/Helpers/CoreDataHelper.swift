import Foundation
import CoreData
import UIKit

struct CoreDataHelper {
  static func managedContext() -> NSManagedObjectContext {
    let managedObjectContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    managedObjectContext.mergePolicy = NSOverwriteMergePolicy
    return managedObjectContext
  }
  static func getFiles() -> [File] {
    let fetchRequest = File.allFilesFetchRequest()
    var files: [File] = []
    do {
      files = try CoreDataHelper.managedContext().fetch(fetchRequest)
    } catch let error as NSError {
      fatalError("Could not fetch. \(error), \(error.userInfo)")
    }
    return files
  }
  static func saveFiles() -> Void {
    do {
      try CoreDataHelper.managedContext().save()
    }
    catch let error as NSError {
      fatalError("Could not save files. \(error), \(error.userInfo)")
    }
  }
  static func truncateFiles() -> Void {
    print("CoreDataHelper.truncateFiles")
    do {
      let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "File")
      let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

      do {
        try CoreDataHelper.managedContext().execute(deleteRequest)
      } catch let error as NSError {
        fatalError("Could not delete files. \(error), \(error.userInfo)")
      }
    }
  }
}
