import Foundation
import CoreData
import UIKit

struct CoreDataHelper {
  static func managedContext() -> NSManagedObjectContext {
    let managedObjectContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    return managedObjectContext
  }
  static func getFiles() -> [File] {
    let fetchRequest = NSFetchRequest<File>(entityName: "File")
    let sortDescriptor = NSSortDescriptor(key: "lastModified", ascending: false)
    fetchRequest.sortDescriptors = [sortDescriptor]
    var files: [File] = []
    do {
      files = try CoreDataHelper.managedContext().fetch(fetchRequest)
    } catch let error as NSError {
      print("Could not fetch. \(error), \(error.userInfo)")
    }
    return files
  }
  static func saveFiles() -> Void {
    do {
      try CoreDataHelper.managedContext().save()
      print("Saved new files.")
    }
    catch {
      fatalError("Unable to save data.")
    }
  }
}
