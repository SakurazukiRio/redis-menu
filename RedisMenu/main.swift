//
//  main.swift
//  RedisMenu
//
//  Created by Mario Alberto Chávez on 31/03/25.
//


import Cocoa

// Check if we can acquire the lock
let canAcquireLock = SingleInstanceManager.shared.acquireLock()

// Check if another instance is running and activate it
let isFirstInstance = AppActivationHandler.shared.checkAndActivateExistingInstance()

if canAcquireLock && isFirstInstance {
    // This is the only instance, proceed with normal launch
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    
    // Override point for customization after application launch.
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    
    // Release the lock when the app terminates
    SingleInstanceManager.shared.releaseLock()
} else {
    // Another instance is already running, exit
    print("Another instance of RedisMenu is already running. Terminating.")
    exit(0)
}
