//
//  ContentView.swift
//  BoringCalorieCounter
//
//  Created by Saxon Thune on 9/27/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var userSettings = UserSettings.shared
    
    @State private var selectedDate = Date()
    @State private var currentDailyEntry: DailyEntry?
    @State private var updateTrigger = 0
    @State private var showingSettings = false
    @State private var showingDatePicker = false
    @State private var showingAddCalories = false
    
    var totalCalories: Int16 {
        _ = updateTrigger
        return currentDailyEntry?.calorieEntries?.compactMap { ($0 as? CalorieEntry)?.calories }.reduce(0, +) ?? 0
    }
    
    var canGoToNextDay: Bool {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        return selectedDate < tomorrow
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    // Settings row
                    HStack {
                        Text("Boring Calorie Counter")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // Grey line separator
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                    
                    // Date navigation row
                    HStack {
                        // Left arrow - go back a day
                        Button(action: {
                            goToPreviousDay()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Center date button - opens date picker
                        Button(action: {
                            withAnimation {
                                showingDatePicker.toggle()
                            }
                        }) {
                            Text(selectedDate, style: .date)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Right arrow - go forward a day (only show if not past tomorrow)
                        if canGoToNextDay {
                            Button(action: {
                                goToNextDay()
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        } else {
                            // Invisible spacer to maintain layout balance
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(.clear)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // Expandable date picker
                    if showingDatePicker {
                        DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .onChange(of: selectedDate) { _ in
                                loadDailyEntry()
                                withAnimation {
                                    showingDatePicker = false
                                }
                            }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Calories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalCalories)/\(currentDailyEntry?.target ?? userSettings.dailyTargetCalories)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            let remaining = (currentDailyEntry?.target ?? userSettings.dailyTargetCalories) - totalCalories
                            Text("\(remaining)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(remaining >= 0 ? .green : .red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundColor(.clear)
                            Button("Add") {
                                showingAddCalories = true
                            }
                            .font(.title2)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // Grey line separator after summary
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color(.systemGray6))
                
                if let dailyEntry = currentDailyEntry {
                    CalorieEntryListView(dailyEntry: dailyEntry) {
                        updateTrigger += 1
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Loading...")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAddCalories) {
                if let dailyEntry = currentDailyEntry {
                    AddCalorieView(dailyEntry: dailyEntry) {
                        updateTrigger += 1
                    }
                }
            }
            .onAppear {
                loadDailyEntry()
            }
        }
    }
    
    private func loadDailyEntry() {
        let persistenceController = PersistenceController.shared
        currentDailyEntry = persistenceController.getDailyEntry(for: selectedDate, in: viewContext)
        
        // Save context if a new daily entry was created
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func goToPreviousDay() {
        let calendar = Calendar.current
        if let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            selectedDate = previousDay
            loadDailyEntry()
        }
    }
    
    private func goToNextDay() {
        let calendar = Calendar.current
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            selectedDate = nextDay
            loadDailyEntry()
        }
    }
}

struct SettingsView: View {
    @StateObject private var userSettings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingBoringUIInfo = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Daily Goals")) {
                    HStack {
                        Text("Target Calories")
                        Spacer()
                        TextField("Target", value: $userSettings.dailyTargetCalories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("TDEE (Total Daily Energy Expenditure)")
                        Spacer()
                        TextField("TDEE", value: $userSettings.tdee, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Section(header: Text("About")) {
                    Button("What is a Boring UI?") {
                        showingBoringUIInfo = true
                    }
                    .foregroundColor(.primary)
                }
                
                Section(footer: Text("Target Calories: Your daily calorie goal\nTDEE: Calories your body burns in a day")) {
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingBoringUIInfo) {
                BoringUIInfoView()
            }
        }
    }
}

struct AddCalorieView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dailyEntry: DailyEntry
    let onUpdate: (() -> Void)
    
    @State private var calories = ""
    @State private var notes = ""
    @State private var showingAddAnotherAlert = false
    
    var sortedEntries: [CalorieEntry] {
        Array(dailyEntry.calorieEntries as? Set<CalorieEntry> ?? []).sorted {
            $0.order < $1.order
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    // Calories input section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calories")
                            .font(.headline)
                        
                        TextField("Enter calories", text: $calories)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numbersAndPunctuation)
                            .font(.title2)
                    }
                    
                    // Quick add buttons
                    VStack(spacing: 12) {
                        // Green positive buttons
                        HStack(spacing: 12) {
                            ForEach([10, 50, 100, 500], id: \.self) { value in
                                Button("+\(value)") {
                                    addToCalories(value)
                                }
                                .foregroundColor(.green)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Red negative buttons
                        HStack(spacing: 12) {
                            ForEach([10, 50, 100, 500], id: \.self) { value in
                                Button("-\(value)") {
                                    subtractFromCalories(value)
                                }
                                .foregroundColor(.red)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Notes input section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        
                        TextField("Enter food description", text: $notes)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Add Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Add Another") {
                            saveCalorieEntryAndAddAnother()
                        }
                        .disabled(calories.isEmpty)
                        
                        Button("Save") {
                            saveCalorieEntry()
                        }
                        .disabled(calories.isEmpty)
                    }
                }
            }
        }
    }
    
    private func addToCalories(_ value: Int) {
        if let currentValue = Int(calories) {
            calories = String(currentValue + value)
        } else {
            calories = String(value)
        }
    }
    
    private func subtractFromCalories(_ value: Int) {
        if let currentValue = Int(calories) {
            let newValue = currentValue - value
            calories = String(newValue)
        } else {
            // If no current value, start with negative value
            calories = String(-value)
        }
    }
    
    private func saveCalorieEntry() {
        guard let calorieValue = Int16(calories) else { return }
        
        withAnimation {
            let newEntry = CalorieEntry(context: viewContext)
            newEntry.id = UUID()
            newEntry.calories = calorieValue
            newEntry.food = notes.isEmpty ? nil : notes
            newEntry.date = Date()
            newEntry.dailyEntry = dailyEntry
            
            let maxOrder = sortedEntries.map { $0.order }.max() ?? 0
            newEntry.order = maxOrder + 1
            
            do {
                try viewContext.save()
                onUpdate()
                dismiss()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func saveCalorieEntryAndAddAnother() {
        guard let calorieValue = Int16(calories) else { return }
        
        withAnimation {
            let newEntry = CalorieEntry(context: viewContext)
            newEntry.id = UUID()
            newEntry.calories = calorieValue
            newEntry.food = notes.isEmpty ? nil : notes
            newEntry.date = Date()
            newEntry.dailyEntry = dailyEntry
            
            let maxOrder = sortedEntries.map { $0.order }.max() ?? 0
            newEntry.order = maxOrder + 1
            
            do {
                try viewContext.save()
                onUpdate()
                // Clear the form for another entry
                calories = ""
                notes = ""
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct BoringUIInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("What is a Boring UI?")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.")
                    
                    Text("Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
                    
                    Text("Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.")
                    
                    Text("Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.")
                    
                    Text("Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.")
                }
                .padding()
            }
            .navigationTitle("Boring UI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("ContentView") {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("SettingsView") {
    SettingsView()
}
