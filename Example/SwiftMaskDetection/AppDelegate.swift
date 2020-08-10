import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(_ app: UIApplication,
                   didFinishLaunchingWithOptions opts: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    window!.rootViewController = ViewController()
    window!.makeKeyAndVisible()
    return true
  }
}

