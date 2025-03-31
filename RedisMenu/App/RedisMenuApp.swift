//
//  RedisMenuApp.swift
//  RedisMenu
//
//  Created by Mario Chavez on 31/03/25.
//


//
//  RedisMenuApp.swift
//  RedisMenu
//
//  Created by Mario Alberto Chávez on 31/03/25.
//


import SwiftUI

struct RedisMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Check if another instance is running using file lock approach
        if !SingleInstanceManager.shared.acquireLock() {
            // Another instance is running, terminate this one
            print("Another instance of RedisMenu is already running. Terminating.")
            NSApp.terminate(nil)
        }
    }

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}