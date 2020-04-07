import UIKit
import CoreData
import Combine
import AVFoundation
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  private var log: Cancellable?
  private var observation: NSKeyValueObservation?
  private var subscription: Cancellable?
    
  lazy var persistentContainer: NSPersistentContainer = {
      let container = NSPersistentContainer(name: "OfflineMediaDownloader")
      container.loadPersistentStores { description, error in
          if let error = error {
              fatalError("Unable to load persistent stores: \(error)")
          }
      }
      return container
  }()
  
  func setupNotifications(application: UIApplication) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) {
        [weak self] granted, error in
          
        print("Permission granted: \(granted)")
        guard granted else { return }
        self?.getNotificationSettings()
    }
  }
  
  func getNotificationSettings() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      print("Notification settings: \(settings)")
      guard settings.authorizationStatus == .authorized else { return }
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }
  
  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    let audioSession = AVAudioSession.sharedInstance()
    do {
        try audioSession.setCategory(.playback, mode: .moviePlayback)
    }
    catch {
        print("Setting category to AVAudioSessionCategoryPlayback failed.")
    }
    
    setupNotifications(application: application)
    return true
  }
}

// Methods related to registering for notifications
extension AppDelegate {
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register: \(error)")
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      
      print("didRegisterForRemoteNotificationsWithDeviceToken")
      let parameters = [
          "token": deviceToken.map { String(format: "%02.2hhx", $0) }.joined(),
          "UUID": UIDevice.current.identifierForVendor!.uuidString,
          "name": UIDevice.current.name,
          "systemName": UIDevice.current.systemName,
          "systemVersion": UIDevice.current.systemVersion
      ] as [String : Any]
      debugPrint(parameters)
      
      var urlComponents = URLComponents(string: "https://oztga5jjx4.execute-api.us-west-2.amazonaws.com/Prod/files")!
      urlComponents.queryItems = [
          URLQueryItem(name: "ApiKey", value: "pFM2pr7gdm8E0DU87uRk8160s36dl82zQH25Pt60")
      ]
      
      var request = URLRequest(url: urlComponents.url!)
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpMethod = "POST"
      let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
      request.httpBody = jsonData
      
      debugPrint("Sending request")
      debugPrint(request)
      self.subscription = URLSession.shared
        .dataTaskPublisher(for: request)
        .sink(receiveCompletion: { completion in
          if case .failure(let err) = completion {
            print("Retrieving data failed with error \(err)")
          }
        }, receiveValue: { object in
          print("Retrieved object \(object)")
          debugPrint(object.response)
      })
  }
}

// Methods relating to receiving remote notifications
extension AppDelegate {
  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    //self.log = ServerAPI.logEvent(message: "didReceiveRemoteNotification")
    //self.log = ServerAPI.logEvent(message: userInfo)
    
    let managedObjectContext = self.persistentContainer.viewContext
    managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    
    if let aps = userInfo["aps"] as? NSDictionary {
      print("userInfo[aps]")
      debugPrint(aps)
    }
    
    if let file = userInfo["file"] as? NSDictionary {
      debugPrint(file)
      let decoder = JSONDecoder()
      decoder.userInfo[CodingUserInfoKey.context!] = managedObjectContext
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: file)
        let file = try decoder.decode(File.self, from: jsonData)
        debugPrint(file)
        if !FileHelper.fileExists(file: file) {
          try managedObjectContext.save()
          downloadFileInBackground(file: file)
        }
      } catch {
        fatalError("Failure to decode JSON: \(error)")
      }
    }
    completionHandler(.newData)
  }
}

// Methods relating to background downloads
extension AppDelegate: URLSessionDelegate, URLSessionDownloadDelegate {
  func makeSessionConfiguration() -> URLSessionConfiguration {
    let sessionNumber = Int.random(in: 0 ... 500)
    let configuration = URLSessionConfiguration.background(withIdentifier: "MySession\(sessionNumber)")
    configuration.isDiscretionary = true
    configuration.sessionSendsLaunchEvents = false
    configuration.timeoutIntervalForRequest = 180
    return configuration
  }
  
  var session : URLSession {
      get {
          let config = makeSessionConfiguration()
          // Warning: If an URLSession still exists from a previous download, it doesn't create
          // a new URLSession object but returns the existing one with the old delegate object attached!
          config.requestCachePolicy = .returnCacheDataElseLoad
          return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
      }
  }
  
  func downloadFileInBackground(file: File) {
    let task = session.downloadTask(with: file.fileUrl!)
    task.countOfBytesClientExpectsToReceive = file.size!.int64Value
    self.observation = task.progress.observe(\.fractionCompleted) { (progress, _) in
      print("Download progress \(String(Int(progress.fractionCompleted * 100)))")
    }
    print("Resuming task")
    task.resume()
  }
    
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    //self.log = ServerAPI.logEvent(message: "downloadTask.didFinishDownloadingTo \(String(describing: location))")
    guard let url = downloadTask.originalRequest?.url else { return }
    //self.log = ServerAPI.logEvent(message: "downloadTask.didFinishDownloadingFrom \(String(describing: url))")
    do {
      let filePath = FileHelper.filePath(url: url)
      try FileManager.default.copyItem(at: location, to: filePath)
    } catch (let writeError) {
      //self.log = ServerAPI.logEvent(message: "downloadTask.didFinishDownloadingTo.error \(String(describing: writeError))")
    }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard error != nil else { return }
    //self.log = ServerAPI.logEvent(message: "downloadTask.didCompleteWithError \(String(describing: error))")
  }
  }
