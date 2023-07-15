import UIKit
import CoreData
import Combine
import AVFoundation
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  private var logSink: Cancellable?
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
        
      //print("Permission granted: \(granted)")
      guard granted else { return }
      self?.getNotificationSettings()
    }
  }
  
  func getNotificationSettings() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      //print("Notification settings: \(settings)")
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
    
    #if !targetEnvironment(simulator)
      setupNotifications(application: application)
      //KeychainHelper.deleteToken()
      //KeychainHelper.deleteUserData()
      //KeychainHelper.deleteDeviceData()
    #endif
    return true
  }
}

// Methods related to registering for notifications
extension AppDelegate {
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    self.logSink = Server.logEvent(message: Data("didFailToRegisterForRemoteNotificationsWithError: \(error)".utf8))
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    self.logSink = Server.logEvent(message: Data("didRegisterForRemoteNotificationsWithDeviceToken".utf8))
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    self.subscription = Server.registerDevice(token: token).sink(
      receiveCompletion: { completion in
        // Two cases:
        // 1: user already registered and token is invalid
        // 2: user hasn't registered and the request just failed
        if case .failure(let err) = completion {
          print("Failed to register device with error \(err)")
          debugPrint(completion)
        }
      }, receiveValue: { response in
        let deviceData = DeviceData(endpointArn: response.body.endpointArn)
        KeychainHelper.storeDeviceData(deviceData: deviceData)
      }
    )
  }
}

// Methods relating to receiving remote notifications
extension AppDelegate {
  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    self.logSink = Server.logEvent(message: Data("didReceiveRemoteNotification".utf8))
    
    if let aps = userInfo["aps"] as? NSDictionary {
      print("userInfo[aps]")
      debugPrint(aps)
      if (aps["health"] != nil) {
        print ("Recieved healthcheck")
        // TODO: Send a request to the server to complete the cycle
      }
    }
    
    if let file = userInfo["file"] as? NSDictionary {
      debugPrint(file)
      let decoder = JSONDecoder()
      decoder.userInfo[CodingUserInfoKey.context!] = CoreDataHelper.managedContext()
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: file)
        self.logSink = Server.logEvent(message: jsonData)
        let file = try decoder.decode(File.self, from: jsonData)
        if !FileHelper.fileExists(file: file) {
          CoreDataHelper.saveFiles()
          downloadFileInBackground(file: file)
        }
      } catch {
        self.logSink = Server.logEvent(message: Data("Failure to decode JSON: \(error)".utf8))
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
    configuration.isDiscretionary = false
    configuration.sessionSendsLaunchEvents = true
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
    let task = session.downloadTask(with: file.url!)
    task.countOfBytesClientExpectsToReceive = file.size!.int64Value
    self.observation = task.progress.observe(\.fractionCompleted) { (progress, _) in
      print("Download progress \(String(Int(progress.fractionCompleted * 100)))")
    }
    print("Resuming task")
    task.resume()
  }
    
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    self.logSink = Server.logEvent(message: Data("downloadTask.didFinishDownloadingTo \(String(describing: location))".utf8))
    guard let url = downloadTask.originalRequest?.url else { return }
    self.logSink = Server.logEvent(message: Data("downloadTask.didFinishDownloadingFrom \(String(describing: url))".utf8))
    do {
      let filePath = FileHelper.filePath(url: url)
      try FileManager.default.copyItem(at: location, to: filePath)
      EventHelper.emit(event: BackgroundDownloadComplete())
    } catch (let writeError) {
      self.logSink = Server.logEvent(message: Data("downloadTask.didFinishDownloadingTo.error \(String(describing: writeError))".utf8))
    }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard error != nil else { return }
    self.logSink = Server.logEvent(message: Data("downloadTask.didCompleteWithError \(String(describing: error))".utf8))
  }
}
