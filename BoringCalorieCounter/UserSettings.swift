//
//  UserSettings.swift
//  BoringCalorieCounter
//
//  Created by Saxon Thune on 9/27/25.
//

import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @Published var dailyTargetCalories: Int16 {
        didSet {
            UserDefaults.standard.set(dailyTargetCalories, forKey: "dailyTargetCalories")
        }
    }
    
    @Published var tdee: Int16 {
        didSet {
            UserDefaults.standard.set(tdee, forKey: "tdee")
        }
    }
    
    private init() {
        self.dailyTargetCalories = Int16(UserDefaults.standard.object(forKey: "dailyTargetCalories") as? Int ?? 1750)
        self.tdee = Int16(UserDefaults.standard.object(forKey: "tdee") as? Int ?? 2250)
    }
}