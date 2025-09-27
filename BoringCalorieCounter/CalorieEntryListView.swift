//
//  CalorieEntryListView.swift
//  BoringCalorieCounter
//
//  Created by Saxon Thune on 9/27/25.
//

import SwiftUI
import CoreData

struct CalorieEntryListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var dailyEntry: DailyEntry
    let onUpdate: (() -> Void)
    
    var sortedEntries: [CalorieEntry] {
        Array(dailyEntry.calorieEntries as? Set<CalorieEntry> ?? []).sorted {
            $0.order < $1.order
        }
    }
    
    var body: some View {
        List {
            if sortedEntries.isEmpty {
                VStack {
                    Text("No entries yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Text("Tap 'Add' to create your first calorie entry")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .listRowBackground(Color(.systemGray6))
            } else {
                ForEach(sortedEntries, id: \.id) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: "line.horizontal.3")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        HStack(spacing: 2) {
                            Text("\(entry.calories)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("cal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 70, alignment: .leading)
                        
                        Spacer()
                        
                        Text(entry.food ?? "")
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    .listRowBackground(Color(.systemGray6))
                }
                .onDelete(perform: deleteEntries)
                .onMove(perform: moveEntries)
            }
        }
        .listStyle(PlainListStyle())
        .background(Color(.systemGray6))
    }

    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            offsets.map { sortedEntries[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
                onUpdate()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func moveEntries(from source: IndexSet, to destination: Int) {
        withAnimation {
            var entries = sortedEntries
            entries.move(fromOffsets: source, toOffset: destination)
            
            // Update order values for all entries
            for (index, entry) in entries.enumerated() {
                entry.order = Int16(index)
            }
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

extension CalorieEntryListView {
    init(dailyEntry: DailyEntry) {
        self.dailyEntry = dailyEntry
        self.onUpdate = {}
    }
}
