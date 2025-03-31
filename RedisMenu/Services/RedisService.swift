//
//  RedisService.swift
//  RedisMenu
//
//  Created by Mario Chavez on 31/03/25.
//

import Foundation
import Cocoa

class RedisService: ObservableObject {
    static let shared = RedisService()
    
    private var redisServerProcess: Process?
    private var standardOutput: Pipe?
    private var standardError: Pipe?
    
    // Add port property
    @Published var port: Int = 6379 // Default Redis port
    
    @Published var isRunning: Bool = false {
        didSet {
            // Post notification when status changes
            NotificationCenter.default.post(name: NSNotification.Name("RedisStatusChanged"), object: isRunning)
        }
    }
    
    init() {
        // Ensure default directories exist
        setupDefaultDirectories()
    }
    
    private func setupDefaultDirectories() {
        let defaults = UserDefaults.standard
        
        // Set default port if not already set
        if UserDefaults.standard.object(forKey: "RedisPort") == nil {
            UserDefaults.standard.set(6379, forKey: "RedisPort")
        }
        
        // Load port from UserDefaults
        port = UserDefaults.standard.integer(forKey: "RedisPort")
        
        // Set default directories if not set already
        if defaults.string(forKey: "RedisDataDir") == nil {
            let defaultDataDir = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/redis/data"
            defaults.set(defaultDataDir, forKey: "RedisDataDir")
        }
        
        if defaults.string(forKey: "RedisLogPath") == nil {
            let defaultLogPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/state/redis/logs/redis.log"
            defaults.set(defaultLogPath, forKey: "RedisLogPath")
        }
        
        // Create data directory if it doesn't exist
        let dataDir = defaults.string(forKey: "RedisDataDir")!
        do {
            try FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Error creating data directory: \(error)")
        }
        
        // Create log directory if it doesn't exist
        let logPath = defaults.string(forKey: "RedisLogPath")!
        let logDir = URL(fileURLWithPath: logPath).deletingLastPathComponent().path
        do {
            try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Error creating log directory: \(error)")
        }
    }

    func startRedis() {
        // Check if already running
        if isRunning { return }
        
        // Find Redis binary path
        guard let resourcePath = Bundle.main.resourcePath else {
            print("Unable to find resource path")
            return
        }
        
        let redisServerPath = "\(resourcePath)/redis/bin/redis-server"
        
        // Debug log
        print("Looking for Redis at: \(redisServerPath)")
        
        // Check if file exists and is executable
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: redisServerPath, isDirectory: &isDirectory)
        
        guard fileExists && !isDirectory.boolValue else {
            print("Redis binary not found at path: \(redisServerPath)")
            // Notify user with an alert
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Redis Binary Not Found"
                alert.informativeText = "Unable to find Redis binary at: \(redisServerPath) \nPlease reinstall the application."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        
        // Check if file is executable
        let attributes = try? FileManager.default.attributesOfItem(atPath: redisServerPath)
        let permissions = attributes?[.posixPermissions] as? NSNumber
        let isExecutable = (permissions?.intValue ?? 0) & 0o111 != 0
        
        guard isExecutable else {
            print("Redis binary is not executable")
            try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: redisServerPath)
            print("Attempted to set executable permissions")
            return
        }
        
        print("Redis binary found and is executable")
        
        // Get directory paths from UserDefaults
        let defaults = UserDefaults.standard
        let dataDir = defaults.string(forKey: "RedisDataDir") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/redis/data"
        let logPath = defaults.string(forKey: "RedisLogPath") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/state/redis/logs/redis.log"
        
        // Create directories if they don't exist
        do {
            try FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: logPath).deletingLastPathComponent().path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Error creating directories: \(error)")
            return
        }
        
        // Check if another instance of Redis is already running
        if isRedisAlreadyRunning() {
            displayAlert(title: "Redis Already Running",
                         message: "Another Redis instance appears to be running. Please stop it before starting a new instance.")
            return
        }
        
        // Get path to Redis binary
        let bundlePath = Bundle.main.resourcePath!
        let binaryPath = "\(bundlePath)/redis/bin/redis-server"
        
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            NSLog("Redis binary not found at path: \(binaryPath)")
            displayAlert(title: "Redis Error", message: "Redis binary not found. Please reinstall the application.")
            return
        }
        
        // Create a configuration file
        let configPath = createConfigFile(dataDir: dataDir, logPath: logPath)
        
        // Configure and start the process
        redisServerProcess = Process()
        redisServerProcess?.executableURL = URL(fileURLWithPath: binaryPath)
        
        // Pass the config file to redis-server
        redisServerProcess?.arguments = [configPath]
        
        // Set up pipes for capturing output
        standardOutput = Pipe()
        standardError = Pipe()
        redisServerProcess?.standardOutput = standardOutput
        redisServerProcess?.standardError = standardError
        
        // Handle process termination
        redisServerProcess?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if let strongSelf = self, strongSelf.isRunning {
                    strongSelf.isRunning = false
                    
                    // Check if terminated unexpectedly with error
                    if process.terminationStatus != 0 && process.terminationStatus != 15 { // 15 is SIGTERM
                        strongSelf.checkLogForErrors(logPath: logPath)
                    }
                    
                    NSLog("Redis process terminated with status: \(process.terminationStatus)")
                }
            }
        }
        
        // Start the Redis process
        do {
            try redisServerProcess?.run()
            isRunning = true
            NSLog("Redis started with data directory: \(dataDir) and log path: \(logPath)")
            
            // Log any output
            setupOutputMonitoring()
        } catch {
            NSLog("Error starting Redis: \(error)")
            displayAlert(title: "Redis Error", message: "Failed to start Redis: \(error.localizedDescription)")
            isRunning = false
        }
    }

    func stopRedis(completion: (() -> Void)? = nil) {
        guard let process = redisServerProcess, isRunning else {
            completion?()
            return
        }
        
        NSLog("Stopping Redis...")
        
        // First try to shut down gracefully using redis-cli
        tryGracefulShutdown()
        
        // Set up a timer to check if the process has terminated
        let shutdownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            // Check if process has terminated
            if self?.isRunning == false || process.isRunning == false {
                timer.invalidate()
                
                // Clean up
                self?.redisServerProcess = nil
                self?.standardOutput = nil
                self?.standardError = nil
                self?.isRunning = false
                
                NSLog("Redis stopped successfully")
                
                // Call completion handler
                completion?()
            }
        }
        
        // Wait a moment for graceful shutdown to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if shutdownTimer.isValid {
                shutdownTimer.invalidate()
                
                // Force terminate if still running
                if process.isRunning {
                    NSLog("Redis shutdown timed out, forcing termination")
                    process.terminate()
                }
                
                // Clean up
                self.redisServerProcess = nil
                self.standardOutput = nil
                self.standardError = nil
                self.isRunning = false
                
                NSLog("Redis forced to stop")
                
                // Call completion handler
                completion?()
            }
        }
    }
    
    private func createConfigFile(dataDir: String, logPath: String) -> String {
        let tempDir = NSTemporaryDirectory()
        let configPath = "\(tempDir)/redis-\(UUID().uuidString).conf"
        
        let configContent = """
        # RedisMenu generated configuration
        port \(port)
        dir \(dataDir)
        logfile \(logPath)
        daemonize no
        """
        
        do {
            try configContent.write(toFile: configPath, atomically: true, encoding: .utf8)
            return configPath
        } catch {
            NSLog("Error creating config file: \(error)")
            return ""
        }
    }
    
    private func tryGracefulShutdown() {
        guard let resourcePath = Bundle.main.resourcePath else {
            return
        }
        
        // Check for redis-cli tool
        let redisCliPath = "\(resourcePath)/redis/bin/redis-cli"
        
        guard FileManager.default.fileExists(atPath: redisCliPath) else {
            return
        }
        
        // Try to shut down gracefully
        let shutdownProcess = Process()
        shutdownProcess.executableURL = URL(fileURLWithPath: redisCliPath)
        shutdownProcess.arguments = ["-p", "\(port)", "shutdown"]
        
        do {
            try shutdownProcess.run()
            NSLog("Sent graceful shutdown command to Redis on port \(port)")
        } catch {
            NSLog("Failed to send graceful shutdown: \(error)")
        }
    }
    
    private func isRedisAlreadyRunning() -> Bool {
        // Simple check for port 6379 (default Redis port)
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        checkProcess.arguments = ["-i", ":\(port)"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return !output.isEmpty
        } catch {
            NSLog("Error checking for running Redis: \(error)")
            return false
        }
    }
    
    private func checkLogForErrors(logPath: String) {
        do {
            let logContent = try String(contentsOfFile: logPath, encoding: .utf8)
            let lines = logContent.components(separatedBy: .newlines).reversed()
            
            // Look through the last 50 lines for error messages
            for line in lines.prefix(50) {
                if line.contains("ERR") || line.contains("error") || line.contains("FATAL") {
                    NSLog("Found error in Redis log: \(line)")
                    
                    // If it's a port conflict
                    if line.contains("Address already in use") || line.contains("port") {
                        displayAlert(title: "Redis Error",
                                   message: "Redis failed to start because the port is already in use. Another instance may be running.")
                    }
                    // Check for permission errors
                    else if line.contains("Permission denied") {
                        displayAlert(title: "Redis Error",
                                   message: "Redis failed to start due to permission issues accessing the data or log directories.")
                    }
                    // Otherwise show generic error
                    else {
                        displayAlert(title: "Redis Error",
                                   message: "Redis failed to start. Check the log file for details: \(logPath)")
                    }
                    
                    break
                }
            }
        } catch {
            NSLog("Error reading Redis log: \(error)")
        }
    }
    
    private func setupOutputMonitoring() {
        guard let outputPipe = standardOutput, let errorPipe = standardError else { return }
        
        // Monitor standard output
        DispatchQueue.global(qos: .background).async {
            let outputHandle = outputPipe.fileHandleForReading
            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        NSLog("Redis output: \(output)")
                    }
                }
            }
        }
        
        // Monitor standard error
        DispatchQueue.global(qos: .background).async {
            let errorHandle = errorPipe.fileHandleForReading
            errorHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let error = String(data: data, encoding: .utf8) {
                        NSLog("Redis error: \(error)")
                        
                        // Check for common errors and display appropriate messages
                        if error.contains("Address already in use") {
                            self.displayAlert(title: "Redis Error",
                                           message: "Failed to start Redis: Port already in use")
                        }
                    }
                }
            }
        }
    }
    
    private func displayAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
