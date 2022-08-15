import NotificationCenter

// Device is shaken
extension UIWindow {
  open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    super.motionEnded(motion, with: event)
    EventHelper.emit(event: ToggleDiagnosticMode())
  }
}

struct EventHelper {
  static public var name = Notification.Name("com.publisher.combine")
  static func emit(event: Event) -> Void {
    NotificationCenter.default.post(name: name, object: nil, userInfo: ["event": event])
  }
}
