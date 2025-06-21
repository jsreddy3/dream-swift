//  AppDelegate.swift
import UIKit
import BackgroundTasks
import Infrastructure          // gives us SyncingDreamStore


@MainActor                                         // delegate methods run on main actor
final class AppDelegate: NSObject, UIApplicationDelegate {

    private weak var store: SyncingDreamStore?

    // SwiftUI hands us the store once it’s built.
    func configure(store: SyncingDreamStore) {
        self.store = store
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.dreamfinder.sync",
            using: nil)                                   // main queue; fine
        { [weak storeRef = store] task in                 // @Sendable by default

            // Start the heavy work off-main and keep a handle to it.
            let work = Task(priority: .background) {
                if let store = storeRef {
                    await store.drain()                   // replay offline queue
                }
                scheduleDreamSync()                       // queue the next cycle
                task.setTaskCompleted(success: true)
            }

            // If iOS tells us time’s up, cancel the async job first.
            task.expirationHandler = {
                work.cancel()                             // cooperative-cancel drain()
                task.setTaskCompleted(success: false)
            }
        }

        return true
    }

}
