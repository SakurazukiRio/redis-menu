//
//  PreferencesView.swift
//  RedisMenu
//
//  Created by Mario Alberto Chávez on 31/03/25.
//


import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct PreferencesView: View {
    @AppStorage("RedisDataDir") private var dataDir: String = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/redis/data"
    @AppStorage("RedisLogPath") private var logPath: String = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/state/redis/logs/redis.log"
    @AppStorage("AutoStartRedis") private var autoStartRedis: Bool = true
    @AppStorage("LaunchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("RedisPort") private var redisPort: Int = 6379
    @AppStorage("MaxMemoryPolicy") private var maxMemoryPolicy: String = "noeviction"
    @AppStorage("MaxMemoryMB") private var maxMemoryMB: Int = 0 // 0 means no limit
    
    @State private var showDataDirPicker = false
    @State private var showLogPathPicker = false
    @State private var restartRequired = false
    @State private var selectedTab = 0
    
    @ObservedObject private var redisService = RedisService.shared
    
    // Options for max memory policy
    private let memoryPolicyOptions = [
        "noeviction", // Don't evict, return error on write when memory limit reached
        "allkeys-lru", // Evict less recently used keys first
        "volatile-lru", // Evict less recently used keys with an expire set
        "allkeys-random", // Evict random keys
        "volatile-random", // Evict random keys with an expire set
        "volatile-ttl" // Evict keys with expire set and shortest TTL
    ]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Settings Tab
            settingsView
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(0)
            
            // Advanced Tab
            advancedView
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag(1)
            
            // About Tab
            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            // Update the service with the current port
            redisService.port = redisPort
            
            // Ensure UI reflects the actual UserDefaults value
            let storedValue = UserDefaults.standard.bool(forKey: "AutoStartRedis")
            if autoStartRedis != storedValue {
                autoStartRedis = storedValue
            }
            print("Current auto-start setting: \(autoStartRedis)")
        }
    }
    
    // Settings Tab Content
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Start Redis when app launches", isOn: $autoStartRedis)
                .onChange(of: autoStartRedis) { oldValue, newValue in
                    // Force UserDefaults synchronization
                    UserDefaults.standard.set(newValue, forKey: "AutoStartRedis")
                    UserDefaults.standard.synchronize()
                    print("Auto-start Redis setting changed to: \(newValue)")
                }
            
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { oldValue, newValue in
                    setLaunchAtLogin(newValue)
                }
            
            Divider()
            
            // Add port configuration
            HStack {
                Text("Redis Port:")
                Spacer()
                TextField("", value: $redisPort, formatter: NumberFormatter())
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            .onChange(of: redisPort) { oldValue, newValue in
                restartRequired = redisService.isRunning
            }
            
            HStack {
                Text("Data Directory:")
                Spacer()
                TextField("", text: $dataDir)
                    .frame(minWidth: 200)
                Button("Browse...") {
                    showDataDirPicker = true
                }
                .sheet(isPresented: $showDataDirPicker) {
                    DirectoryPickerView(selectedPath: $dataDir, title: "Select Redis Data Directory")
                }
            }
            .onChange(of: dataDir) { oldValue, newValue in
                restartRequired = redisService.isRunning
            }
            
            HStack {
                Text("Log File Path:")
                Spacer()
                TextField("", text: $logPath)
                    .frame(minWidth: 200)
                Button("Browse...") {
                    showLogPathPicker = true
                }
                .sheet(isPresented: $showLogPathPicker) {
                    FilePickerView(selectedPath: $logPath, title: "Select Redis Log File")
                }
            }
            .onChange(of: logPath) { oldValue, newValue in
                restartRequired = redisService.isRunning
            }
            
            if restartRequired {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                    Text("Changes require Redis restart")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Restart Redis") {
                        restartRedis()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }
            
            HStack {
                Text("Redis Status: \(redisService.isRunning ? "Running" : "Stopped")")
                    .foregroundColor(redisService.isRunning ? .green : .red)
                Spacer()
                Button(redisService.isRunning ? "Stop Redis" : "Start Redis") {
                    if redisService.isRunning {
                        redisService.stopRedis()
                    } else {
                        redisService.startRedis()
                    }
                }
            }
            .padding(.top)
        }
        .padding()
    }
    
    // Advanced Tab Content
    private var advancedView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Max Memory Setting
            HStack {
                Text("Max Memory (MB):")
                Spacer()
                TextField("", value: $maxMemoryMB, formatter: NumberFormatter())
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            Text("0 = no memory limit")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Max Memory Policy:")
                Spacer()
                Picker("", selection: $maxMemoryPolicy) {
                    ForEach(memoryPolicyOptions, id: \.self) { policy in
                        Text(policy).tag(policy)
                    }
                }
                .frame(width: 180)
            }
            .onChange(of: maxMemoryPolicy) { oldValue, newValue in
                restartRequired = redisService.isRunning
            }
            
            // Add explanation for selected policy
            Group {
                switch maxMemoryPolicy {
                case "noeviction":
                    explanationText("Don't remove keys when memory limit is reached. Write operations will return errors.")
                case "allkeys-lru":
                    explanationText("Remove least recently used keys first, regardless of expiration settings.")
                case "volatile-lru":
                    explanationText("Remove least recently used keys, but only those with an expiration set.")
                case "allkeys-random":
                    explanationText("Remove random keys to free memory.")
                case "volatile-random":
                    explanationText("Remove random keys, but only those with an expiration set.")
                case "volatile-ttl":
                    explanationText("Remove keys with shorter time-to-live values first.")
                default:
                    EmptyView()
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func explanationText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
    }
    
    // About Tab Content
    private var aboutView: some View {
        VStack(spacing: 20) {
            // Company Logo
            Image("CompanyLogo") // Add your company logo to Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .padding(.top, 20)
            
            // App Name
            Text("RedisMenu")
                .font(.system(size: 24, weight: .bold))
            
            // Version
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Company Name
            Text("Maquina App")
                .font(.headline)
                .padding(.top, 10)
            
            // URL (clickable)
            Link("https://maquina.app", destination: URL(string: "https://maquina.app")!)
                .font(.subheadline)
                .foregroundColor(.blue)
            
            // Copyright
            Text("© \(Calendar.current.component(.year, from: Date())) Maquina App. All rights reserved.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 10)
            
            // Redis Trademark Disclaimer
            VStack(spacing: 0) {
                Text("Redis and the Redis logo are registered")
                Text("trademarks of Redis Ltd.")
            }
            .font(.caption2)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
            .padding(.top, 5)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        #if os(macOS)
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Error setting launch at login: \(error)")
        }
        #endif
    }
    
    private func restartRedis() {
        if redisService.isRunning {
            redisService.stopRedis()
            // Small delay to ensure proper shutdown
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                redisService.startRedis()
                restartRequired = false
            }
        }
    }
}

// Directory Picker View
struct DirectoryPickerView: View {
    @Binding var selectedPath: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            
            Button("Select Directory") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                
                if panel.runModal() == .OK {
                    selectedPath = panel.url?.path ?? selectedPath
                }
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 150)
    }
}

// File Picker View
struct FilePickerView: View {
    @Binding var selectedPath: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            
            Button("Select File") {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [UTType.log]
                panel.nameFieldStringValue = "redis.log"
                
                if panel.runModal() == .OK {
                    selectedPath = panel.url?.path ?? selectedPath
                }
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 150)
    }
}
