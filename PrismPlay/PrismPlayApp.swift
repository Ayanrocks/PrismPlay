//
//  PrismPlayApp.swift
//  PrismPlay
//
//  Created by Ayan Banerjee on 07/12/25.
//

import SwiftUI
import CoreData

@main
struct PrismPlayApp: App {
    let persistenceController = PersistenceController.shared

    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Clear logic on launch to ensure a fresh session or cleanup old junk
        VideoCacheManager.shared.clearCache()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .inactive {
                        // Optional: Clear cache when app goes background if stricter cleanup is needed
                        // But user asked for "when closing the app", so usually termination or long background.
                        // Relying on `init` covers the "next play" or "restart" scenario.
                        // If we clear on background, we might kill paused video cache if user switches apps.
                        // Better to keep it on background for now to allow resume!
                    }
                }
        }
    }
}
