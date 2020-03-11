//
//  AppDelegate.swift
//  Wildfire1.1
//
//  Created by Thomas Pitts on 12/01/2019.
//  Copyright © 2019 Wildfire. All rights reserved.
//

import UIKit
import FirebaseCore
import Firebase
import LocalAuthentication
import FirebaseAuth
import FirebaseFunctions
import SwiftyJSON
import UserNotifications
//import FBSDKCoreKit
//import FBSDKLoginKit
//import FacebookCore
//import FacebookLogin

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?
    var timestamp: Int64?

    
    lazy var functions = Functions.functions(region:"europe-west1")


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        FirebaseApp.configure()
        
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self

            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings =
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        
        
//        ApplicationDelegate.sharedInstance()?.application(application, didFinishLaunchingWithOptions: launchOptions)
        
//        // used to store profile pic cache key across sessions, to save from having to download it again from Storage
//        let defaults = UserDefaults.standard
//        let defaultValue = ["profilePicCacheKey": ""]
//        defaults.register(defaults: defaultValue)
        
        // check whether the user has completed signup flow 
        if UserDefaults.standard.bool(forKey: "userAccountExists") != true {
            Utilities().checkForUserAccount()
        }
        if UserDefaults.standard.string(forKey: "mangopayID") == nil {
            print("did not find mangopay ID")
            Utilities().getMangopayID()
        }
//        fetchPaymentMethodsListFromMangopay()
//        fetchBankAccountsListFromMangopay()
        redirect()
        setupNavigationBarAppearance()
        return true
    }
    // Update: no longer using Facebook integration for time being so parking this
//    // this is a facebook-specific function required for compatibility with older iOS versions (<9.0 afaik)
//    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
//
//        return ApplicationDelegate.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
//    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        self.timestamp = Date().toSeconds()
        
        // get rid of keyboard - can cause crashes if this line isn't included
        window?.endEditing(true)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        fetchPaymentMethodsListFromMangopay()
        redirect()
        
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
//
//    // probably don't need the following 2 funcs
//    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
//        let token = tokenParts.joined()
//        print("Device Token: \(token)")
//
//    }
//
//    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
//      print("Failed to register: \(error)")
//    }

    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")

        let dataDict:[String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)

        // Note: This callback is fired at each app startup and whenever a new token is generated.
        
        let savedToken = UserDefaults.standard.string(forKey: "fcmToken")
        
        if savedToken != fcmToken {
        
            // replace current saved token
            UserDefaults.standard.set(fcmToken, forKey: "fcmToken")
            
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            let tokenData = [
                "fcmToken": fcmToken
            ]
//            print("didReceiveRegistrationToken was FIRED: " + fcmToken)
            
            Firestore.firestore().collection("users").document(uid).setData(tokenData
            // merge: true is IMPORTANT - prevents complete overwriting of a document if a user logs in for a second time, for example, which could wipe important data
             , merge: true) { (error) in
            }
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification

        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)


        // Print full message.
//        print(userInfo)
        
        if let refusedType = userInfo["refusedType"] as? String {
            print(refusedType)
        }

        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    func redirect() {
        
        // TODO if no connectivity, prevent user from progressing
        
        // check if they are logged in already
        let uid = Auth.auth().currentUser?.uid
        
        let mainStoryboard : UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        
        if uid != nil {
            if let checkoutTime = self.timestamp {
                if checkoutTime > Date().toSeconds() - 60 {
                    
                    
//                    let initialViewController: UIViewController = mainStoryboard.instantiateViewController(withIdentifier: "mainMenu") as UIViewController
//                    self.window = UIWindow(frame: UIScreen.main.bounds)
//                    self.window?.rootViewController = initialViewController
//                    self.window?.makeKeyAndVisible()
                    
                } else {
                    
                    let initialViewController: UIViewController = mainStoryboard.instantiateViewController(withIdentifier: "HomeVC") as UIViewController
                    self.window = UIWindow(frame: UIScreen.main.bounds)
                    self.window?.rootViewController = initialViewController
                    self.window?.makeKeyAndVisible()
                    
                }
            } else {
                
                let initialViewController: UIViewController = mainStoryboard.instantiateViewController(withIdentifier: "HomeVC") as UIViewController
                self.window = UIWindow(frame: UIScreen.main.bounds)
                self.window?.rootViewController = initialViewController
                self.window?.makeKeyAndVisible()
                
            }
            
        } else {
            let initialViewController: UIViewController = mainStoryboard.instantiateViewController(withIdentifier: "verifyMobile") as UIViewController
            self.window = UIWindow(frame: UIScreen.main.bounds)
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
            
        }
    }
    
    func fetchPaymentMethodsListFromMangopay() {
        
        functions.httpsCallable("listCards").call() { (result, error) in

            if let cardList = result?.data as? [[String: Any]] {
                let defaults = UserDefaults.standard
                
                defaults.set(cardList.count, forKey: "numberOfCards")
                
                let count = cardList.count
                
                if count > 0 {
                    for i in 1...count {
                        var cardNumber = ""
                        var cardProvider = ""
                        var expiryDate = ""
                        
                        let blob1 = cardList[i-1]
                        if let cn = blob1["Alias"] as? String, let cp = blob1["CardProvider"] as? String, let ed = blob1["ExpirationDate"] as? String {
                            
                            cardNumber = String(cn.suffix(8))
                            cardProvider = cp
                            expiryDate = ed
                        }
                        let card = PaymentCard(cardNumber: cardNumber, cardProvider: cardProvider, expiryDate: expiryDate)
                        
                        defaults.set(try? PropertyListEncoder().encode(card), forKey: "card\(i)")
                    }
                }
                
            } else {
                print("nope")
            }
        }
    }
    
    func fetchBankAccountsListFromMangopay() {
        functions.httpsCallable("listBankAccounts").call() { (result, error) in

        if let bankAccountList = result?.data as? [[String: Any]] {
            let defaults = UserDefaults.standard

            defaults.set(bankAccountList.count, forKey: "numberOfBankAccounts")

            let count = bankAccountList.count

            print(bankAccountList)

            if count > 0 {
                for i in 1...count {
                    var cardNumber = ""
                    var cardProvider = ""
                    var expiryDate = ""
                    
                    var accountHolderName = ""
                    var type = ""
                    var IBAN = ""
                    var SWIFTBIC = ""
                    var accountNumber = ""
                    var country = ""

                    let blob1 = bankAccountList[i-1]
                    
                    if let nm = blob1["OwnerName"] as? String, let tp = blob1["Type"] as? String {
                        accountHolderName = nm
                        type = tp
                    }
                    
                    if let ib = blob1["IBAN"] as? String {
                        IBAN = ib
                    }
                    
                    if let sb = blob1["BIC"] as? String {
                        SWIFTBIC = sb
                    }
                    
                    if let an = blob1["AccountNumber"] as? String {
                        accountNumber = an
                    }

                    if let cn = blob1["Country"] as? String {
                        country = cn
                    }
                    
                    let bankAccount = BankAccount(accountHolderName: accountHolderName, type: type, IBAN: IBAN, SWIFTBIC: SWIFTBIC, accountNumber: accountNumber, country: country)

                    // save BankAccount object to User Defaults
                    defaults.set(try? PropertyListEncoder().encode(bankAccount), forKey: "bankAccount\(i)")
                }
            }

        } else {
        print("nope")
        }
        }
    }
    

    func setupNavigationBarAppearance() {
////        UINavigationBar.appearance().barTintColor = .blue
////        UINavigationBar.appearance().tintColor = .white
////        UINavigationBar.appearance().isTranslucent = false
//
//        UINavigationBar.appearance().backgroundColor = .green
//        UINavigationBar.appearance().tintColor = .white
//
//
////        let font: UIFont = UIFont(name: "Helvetica", size: 18.0)!
//        let navbarTitleAtt = [
////            NSAttributedString.Key.font:font,
//            NSAttributedString.Key.foregroundColor: UIColor.white
//        ]
//        UINavigationBar.appearance().titleTextAttributes = navbarTitleAtt
        
        if #available(iOS 13.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithTransparentBackground()
            navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
//            navBarAppearance.backgroundColor = Style.secondaryThemeColour

            UINavigationBar.appearance().standardAppearance = navBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
            
            
        }
    }
}

extension Date {
    func toSeconds() -> Int64! {
        return Int64(self.timeIntervalSince1970)
    }
}

