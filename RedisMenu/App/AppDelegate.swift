//
//  AppDelegate.swift
//  RedisMenu
//
//  Created by Mario Alberto Chávez on 31/03/25.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var menu: NSMenu?
    var preferencesWindow: NSWindow?
    
    @Published var redisStatus: String = "Starting..."
    
    // Subscribe to Redis service status changes
    private var redisStatusObserver: NSObjectProtocol?
    
    // Unique identifier for this app
    private let appIdentifier = "com.maquina-app.RedisMenu"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if another instance is already running
        if !ensureSingleInstance() {
            NSApp.terminate(nil)
            return
        }
        
        print("Application did finish launching")
        // Set up menu bar status item
        setupMenuBar()
        print("Menu bar setup complete")
        
        // Start Redis if auto-start is enabled
        if UserDefaults.standard.bool(forKey: "AutoStartRedis") {
            print("Autostart enabled. Starting Redis...")
            startRedis()
        } else {
            redisStatus = "Stopped"
            updateStatusDisplay()
        }
        
        // Setup observer for Redis service status changes
        redisStatusObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RedisStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isRunning = notification.object as? Bool {
                self?.redisStatus = isRunning ? "Running" : "Stopped"
                self?.updateStatusDisplay()
            }
        }
        
        // Register for notifications when app is being activated
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleAppActivationRequest),
            name: NSNotification.Name("\(appIdentifier).ActivateApp"),
            object: nil
        )
    }
    
    private func ensureSingleInstance() -> Bool {
        // Post a notification to alert any existing instances
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("\(appIdentifier).ActivateApp"),
            object: Bundle.main.bundleIdentifier,
            userInfo: nil,
            deliverImmediately: true
        )
        
        // Small delay to allow existing app to respond
        Thread.sleep(forTimeInterval: 0.5)
        
        // Check if we received a response (handled in the notification callback)
        // If we return false from this method in the callback, the app will terminate
        return true
    }
    
    @objc private func handleAppActivationRequest(notification: NSNotification) {
        // Check if this is from another instance trying to launch
        if notification.object as? String != Bundle.main.bundleIdentifier {
            // Bring app to foreground
            NSApp.activate(ignoringOtherApps: true)
            
            // Show preferences window if it exists
            if let window = preferencesWindow {
                window.makeKeyAndOrderFront(nil)
            } else {
                openPreferences()
            }
            
            // Update notification center to indicate we're already running
            // This will cause the other instance to terminate
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("\(appIdentifier).AlreadyRunning"),
                object: Bundle.main.bundleIdentifier,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }
    
    deinit {
        if let observer = redisStatusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                // Configure the image first
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                
                // Then assign it to the button
                button.image = icon
                print("Image set: \(String(describing: button.image))")
            } else {
                // Fallback if image can't be loaded
                print("Failed to load MenuBarIcon, using text fallback")
                button.title = "R"
            }
        }

        menu = NSMenu()
        menu?.addItem(NSMenuItem(title: "Redis Status: \(redisStatus)", action: nil, keyEquivalent: ""))
        menu?.addItem(NSMenuItem.separator())
        
        let startStopItem = NSMenuItem(title: "Start Redis", action: #selector(toggleRedis), keyEquivalent: "s")
        startStopItem.target = self
        menu?.addItem(startStopItem)

        menu?.addItem(NSMenuItem.separator())

        let openData = NSMenuItem(title: "Open Data Folder", action: #selector(openDataFolder), keyEquivalent: "d")
        openData.target = self
        menu?.addItem(openData)

        let openLog = NSMenuItem(title: "Open Log Folder", action: #selector(openLogFolder), keyEquivalent: "l")
        openLog.target = self
        menu?.addItem(openLog)

        menu?.addItem(NSMenuItem.separator())

        let preferencesItem = NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu?.addItem(preferencesItem)

        menu?.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }
    
    @objc func toggleRedis() {
        if RedisService.shared.isRunning {
            stopRedis()
        } else {
            startRedis()
        }
    }
    
    func startRedis() {
        RedisService.shared.startRedis()
        updateStatusDisplay()
    }
    
    func stopRedis() {
        RedisService.shared.stopRedis()
        updateStatusDisplay()
    }

    func updateStatusDisplay() {
        // Update menu item title to include port
        menu?.item(at: 0)?.title = "Redis Status: \(redisStatus) (Port: \(RedisService.shared.port))"
        
        // Update start/stop menu item
        if let startStopItem = menu?.item(at: 2) {
            startStopItem.title = RedisService.shared.isRunning ? "Stop Redis" : "Start Redis"
        }
        
        // Update status bar icon if needed
        if let button = statusItem?.button {
            let icon = NSImage(named: "MenuBarIcon")
            if let icon = icon {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            }
        }
    }

    @objc func openDataFolder() {
        let dataDir = UserDefaults.standard.string(forKey: "RedisDataDir") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/redis/data"
        NSWorkspace.shared.open(URL(fileURLWithPath: dataDir))
    }

    @objc func openLogFolder() {
        let logPath = UserDefaults.standard.string(forKey: "RedisLogPath") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/state/redis/logs/redis.log"
        let logDir = URL(fileURLWithPath: logPath).deletingLastPathComponent()
        NSWorkspace.shared.open(logDir)
    }

    @objc func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 220),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            preferencesWindow?.center()
            preferencesWindow?.title = "Redis Preferences"
            preferencesWindow?.contentView = NSHostingView(rootView: PreferencesView())
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Check if Redis is running
        if RedisService.shared.isRunning {
            print("Application is quitting, waiting for Redis to stop...")
            
            // Start Redis shutdown
            RedisService.shared.stopRedis { [weak self] in
                // Once Redis is stopped, tell the app it can terminate now
                print("Redis has stopped, proceeding with app termination")
                DispatchQueue.main.async {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            }
            
            // Tell the app to wait before quitting
            return .terminateLater
        } else {
            // If Redis is not running, we can quit immediately
            return .terminateNow
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop Redis when app is terminated
        RedisService.shared.stopRedis()
    }
}
