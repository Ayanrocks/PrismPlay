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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
