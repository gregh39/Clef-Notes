import CoreData
import UIKit
import RevenueCat

class AppDelegate: UIResponder, UIApplicationDelegate {

    // Helper function to safely retrieve the API key from Info.plist
    private func getAPIKey(named keyName: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: keyName) as? String else {
            fatalError("API Key '\(keyName)' not found in Info.plist. Make sure it's set in your Keys.xcconfig file.")
        }
        return value
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Read the API key from the Info.plist
        let revenueCatAPIKey = getAPIKey(named: "RevenueCatAPIKey")
        
        // Configure Purchases with the key
        Purchases.configure(withAPIKey: revenueCatAPIKey)
        
        // Set the log level for debugging (consider removing for release)
        Purchases.logLevel = .debug
        
        // Set the delegate for the shared instance of SubscriptionManager
        Purchases.shared.delegate = SubscriptionManager.shared
        
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
