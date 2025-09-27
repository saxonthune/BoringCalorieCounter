//
//  BoringCalorieCounterApp.swift
//  BoringCalorieCounter
//
//  Created by Saxon Thune on 9/27/25.
//

import SwiftUI

@main
struct BoringCalorieCounterApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
