import UIKit
import Combine
import AVFoundation
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var subscription: Cancellable?
    
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
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        debugPrint(userInfo)
        debugPrint(userInfo[AnyHashable("key")])
        completionHandler(.newData)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
      print("Failed to register: \(error)")
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        print("didRegisterForRemoteNotificationsWithDeviceToken")
        let parameters = [
            "Token": deviceToken.map { String(format: "%02.2hhx", $0) }.joined(),
            "UUID": UIDevice.current.identifierForVendor!.uuidString,
            "Name": UIDevice.current.name,
            "SystemName": UIDevice.current.systemName,
            "SystemVersion": UIDevice.current.systemVersion
        ] as [String : Any]
        debugPrint(parameters)
        
        var urlComponents = URLComponents(string: "https://zc21p8daqc.execute-api.us-west-2.amazonaws.com/Prod/registerDevice")!
        urlComponents.queryItems = [
            URLQueryItem(name: "ApiKey", value: "pRauC0NteI2XM5zSLgDzDaROosvnk1kF1H0ID2zc")
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
