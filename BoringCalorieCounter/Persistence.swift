//
//  Persistence.swift
//  BoringCalorieCounter
//
//  Created by Saxon Thune on 9/27/25.
//

import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        let sampleDailyEntry = DailyEntry(context: viewContext)
        sampleDailyEntry.id = UUID()
        sampleDailyEntry.date = Date()
        sampleDailyEntry.target = 1750
        
        let sampleCalorieEntry = CalorieEntry(context: viewContext)
        sampleCalorieEntry.id = UUID()
        sampleCalorieEntry.food = "Apple"
        sampleCalorieEntry.calories = 80
        sampleCalorieEntry.date = Date()
        sampleCalorieEntry.order = 0
        sampleCalorieEntry.dailyEntry = sampleDailyEntry
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BoringCalorieCounter")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        migrateExistingEntries()
    }
    
    func getDailyEntry(for date: Date, in context: NSManagedObjectContext) -> DailyEntry {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<DailyEntry> = DailyEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.fetchLimit = 1
        
        do {
            let dailyEntries = try context.fetch(request)
            if let existingEntry = dailyEntries.first {
                return existingEntry
            } else {
                let newEntry = DailyEntry(context: context)
                newEntry.id = UUID()
                newEntry.date = startOfDay
                newEntry.target = UserSettings.shared.dailyTargetCalories
                return newEntry
            }
        } catch {
            fatalError("Failed to fetch or create daily entry: \(error)")
        }
    }
    
    private func migrateExistingEntries() {
        let context = container.viewContext
        let request: NSFetchRequest<CalorieEntry> = CalorieEntry.fetchRequest()
        
        do {
            let entries = try context.fetch(request)
            
            let groupedEntries = Dictionary(grouping: entries) { $0.dailyEntry }
            
            for (_, dailyEntries) in groupedEntries {
                let sortedByDate = dailyEntries.sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
                
                for (index, entry) in sortedByDate.enumerated() {
                    if entry.order == 0 && index > 0 {
                        entry.order = Int16(index)
                    }
                }
            }
            
            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("Failed to migrate existing entries: \(error)")
        }
    }
}
