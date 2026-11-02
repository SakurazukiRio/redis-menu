//
//  RedisService.swift
//  RedisMenu
//
//  Created by Mario Alberto Chávez on 31/03/25.
//

import Foundation
import Cocoa

class RedisService: ObservableObject {
    static let shared = RedisService()
    
    private var redisServerProcess: Process?
    private var standardOutput: Pipe?
    private var standardError: Pipe?
    
    // 监听端口属性
    @Published var port: Int = 6379 // 默认 Redis 端口
    
    // Redis 运行状态
    @Published var isRunning: Bool = false {
        didSet {
            // 当状态改变时发送通知
            NotificationCenter.default.post(name: NSNotification.Name("RedisStatusChanged"), object: isRunning)
        }
    }
    
    init() {
        // 确保默认目录存在
        setupDefaultDirectories()
    }
    
    /// 初始化默认目录与配置
    private func setupDefaultDirectories() {
        let defaults = UserDefaults.standard
        
        // 如果未设置端口，设置默认端口 6379
        if UserDefaults.standard.object(forKey: "RedisPort") == nil {
            UserDefaults.standard.set(6379, forKey: "RedisPort")
        }
        
        // 从 UserDefaults 加载端口
        port = UserDefaults.standard.integer(forKey: "RedisPort")
        
        // 如果未设置默认数据和日志目录，则进行初始化
        if defaults.string(forKey: "RedisDataDir") == nil {
            let defaultDataDir = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/redis/data"
            defaults.set(defaultDataDir, forKey: "RedisDataDir")
        }
        
        if defaults.string(forKey: "RedisLogPath") == nil {
            let defaultLogPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/state/redis/logs/redis.log"
            defaults.set(defaultLogPath, forKey: "RedisLogPath")
        }
        
        // 如果数据目录不存在则创建
        let dataDir = defaults.string(forKey: "RedisDataDir")!
        do {
            try FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("创建数据目录失败: \(error)")
        }
        
        // 如果日志目录不存在则创建
        let logPath = defaults.string(forKey: "RedisLogPath")!
        let logDir = URL(fileURLWithPath: logPath).deletingLastPathComponent().path
        do {
            try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("创建日志目录失败: \(error)")
        }
    }

    /// 查找 redis-server 可执行文件路径
    /// 优先级：用户设置 > 应用内捆绑 > 用户本地工具目录(/Users/arona/tools/redis) > 系统常见路径
    func findRedisServerBinary() -> String? {
        let defaults = UserDefaults.standard
        
        // 1. 检查用户在偏好设置中自定义的路径
        if let customPath = defaults.string(forKey: "RedisServerPath"), !customPath.isEmpty {
            if FileManager.default.isExecutableFile(atPath: customPath) {
                return customPath
            }
        }
        
        // 2. 检查应用包内的捆绑路径
        if let resourcePath = Bundle.main.resourcePath {
            let bundleBinary = "\(resourcePath)/redis/bin/redis-server"
            if FileManager.default.isExecutableFile(atPath: bundleBinary) {
                return bundleBinary
            }
        }
        
        // 3. 检查用户本地目录（例如 /Users/arona/tools/redis）
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let localCandidatePaths = [
            "\(homeDir)/tools/redis/src/redis-server",
            "\(homeDir)/tools/redis/bin/redis-server",
            "/Users/arona/tools/redis/src/redis-server",
            "/Users/arona/tools/redis/bin/redis-server"
        ]
        for path in localCandidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // 4. 检查系统常见路径 (Homebrew / 系统路径)
        let systemCandidatePaths = [
            "/opt/homebrew/bin/redis-server",
            "/usr/local/bin/redis-server",
            "/usr/bin/redis-server"
        ]
        for path in systemCandidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        return nil
    }

    /// 查找 redis-cli 可执行文件路径
    func findRedisCliBinary() -> String? {
        let defaults = UserDefaults.standard
        
        if let customPath = defaults.string(forKey: "RedisCliPath"), !customPath.isEmpty {
            if FileManager.default.isExecutableFile(atPath: customPath) {
                return customPath
            }
        }
        
        if let resourcePath = Bundle.main.resourcePath {
            let bundleBinary = "\(resourcePath)/redis/bin/redis-cli"
            if FileManager.default.isExecutableFile(atPath: bundleBinary) {
                return bundleBinary
            }
        }
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let localCandidatePaths = [
            "\(homeDir)/tools/redis/src/redis-cli",
            "\(homeDir)/tools/redis/bin/redis-cli",
            "/Users/arona/tools/redis/src/redis-cli",
            "/Users/arona/tools/redis/bin/redis-cli"
        ]
        for path in localCandidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        let systemCandidatePaths = [
            "/opt/homebrew/bin/redis-cli",
            "/usr/local/bin/redis-cli",
            "/usr/bin/redis-cli"
        ]
        for path in systemCandidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        return nil
    }

    /// 获取当前 Redis 核心版本号（例如 8.10.2）
    func getRedisVersion() -> String {
        guard let serverPath = findRedisServerBinary() else {
            return "未检测到"
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: serverPath)
        process.arguments = ["--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if let range = output.range(of: "v=[0-9.]+", options: .regularExpression) {
                    let vStr = String(output[range])
                    return vStr.replacingOccurrences(of: "v=", with: "")
                }
            }
        } catch {
            NSLog("获取 Redis 版本失败: \(error)")
        }
        return "8.x (最新版)"
    }

    /// 启动 Redis 服务
    func startRedis() {
        // 如果已在运行，则不重复启动
        if isRunning { return }
        
        // 查找 redis-server 二进制文件路径
        guard let binaryPath = findRedisServerBinary() else {
            NSLog("未找到 redis-server 可执行文件")
            displayAlert(title: "未找到 Redis 可执行文件",
                         message: "未能在应用资源目录、/Users/arona/tools/redis 或系统路径中找到 redis-server。\n请在“偏好设置”中配置正确的 Redis 路径。")
            return
        }
        
        print("使用的 Redis 路径: \(binaryPath)")
        
        // 检查文件是否有可执行权限
        let attributes = try? FileManager.default.attributesOfItem(atPath: binaryPath)
        let permissions = attributes?[.posixPermissions] as? NSNumber
        let isExecutable = (permissions?.intValue ?? 0) & 0o111 != 0
        
        if !isExecutable {
            print("Redis 二进制文件无可执行权限，尝试添加权限...")
            try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: binaryPath)
        }
        
        // 从偏好设置获取配置路径
        let defaults = UserDefaults.standard
        let dataDir = defaults.string(forKey: "RedisDataDir") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/redis/data"
        let logPath = defaults.string(forKey: "RedisLogPath") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/state/redis/logs/redis.log"
        
        // 确保数据和日志目录存在
        do {
            try FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: logPath).deletingLastPathComponent().path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("创建运行目录失败: \(error)")
            displayAlert(title: "目录创建失败", message: "无法创建 Redis 数据或日志目录：\(error.localizedDescription)")
            return
        }
        
        // 检查端口是否已被其他 Redis 或程序占用
        if isRedisAlreadyRunning() {
            displayAlert(title: "端口已被占用",
                         message: "端口 \(port) 已被占用，可能有另一个 Redis 实例正在运行。请先停止它，或在设置中更换端口。")
            return
        }
        
        // 生成临时配置文件
        let configPath = createConfigFile(dataDir: dataDir, logPath: logPath)
        guard !configPath.isEmpty else {
            displayAlert(title: "配置生成失败", message: "无法生成 Redis 配置文件，请检查临时目录权限。")
            return
        }
        
        // 配置并启动子进程
        redisServerProcess = Process()
        redisServerProcess?.executableURL = URL(fileURLWithPath: binaryPath)
        redisServerProcess?.arguments = [configPath]
        
        // 设置输出重定向管道
        standardOutput = Pipe()
        standardError = Pipe()
        redisServerProcess?.standardOutput = standardOutput
        redisServerProcess?.standardError = standardError
        
        // 监听进程终止事件
        redisServerProcess?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if let strongSelf = self, strongSelf.isRunning {
                    strongSelf.isRunning = false
                    
                    // 非正常退出（15 为 SIGTERM 正常终止信号）
                    if process.terminationStatus != 0 && process.terminationStatus != 15 {
                        strongSelf.checkLogForErrors(logPath: logPath)
                    }
                    
                    NSLog("Redis 进程已退出，退出码: \(process.terminationStatus)")
                }
            }
        }
        
        // 运行进程
        do {
            try redisServerProcess?.run()
            isRunning = true
            NSLog("Redis 已成功启动，数据目录: \(dataDir)，日志路径: \(logPath)，端口: \(port)")
            
            // 启动输出监控
            setupOutputMonitoring()
        } catch {
            NSLog("启动 Redis 出现异常: \(error)")
            displayAlert(title: "Redis 启动失败", message: "无法启动 Redis：\(error.localizedDescription)")
            isRunning = false
        }
    }

    /// 停止 Redis 服务
    func stopRedis(completion: (() -> Void)? = nil) {
        guard let process = redisServerProcess, isRunning else {
            completion?()
            return
        }
        
        NSLog("正在停止 Redis 服务...")
        
        // 优先使用 redis-cli 优雅关闭
        tryGracefulShutdown()
        
        // 启动定时器轮询进程是否已退出
        let shutdownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            if self?.isRunning == false || process.isRunning == false {
                timer.invalidate()
                
                // 清理资源
                self?.redisServerProcess = nil
                self?.standardOutput = nil
                self?.standardError = nil
                self?.isRunning = false
                
                NSLog("Redis 服务已成功停止")
                completion?()
            }
        }
        
        // 超时保护：5 秒后若未停止则强制终止
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if shutdownTimer.isValid {
                shutdownTimer.invalidate()
                
                if process.isRunning {
                    NSLog("Redis 优雅停止超时，正在强制终止进程...")
                    process.terminate()
                }
                
                self.redisServerProcess = nil
                self.standardOutput = nil
                self.standardError = nil
                self.isRunning = false
                
                NSLog("Redis 进程已被强制停止")
                completion?()
            }
        }
    }
    
    /// 根据当前偏好设置生成 Redis 配置文件
    private func createConfigFile(dataDir: String, logPath: String) -> String {
        let tempDir = NSTemporaryDirectory()
        let configPath = "\(tempDir)/redis-\(UUID().uuidString).conf"
        
        let defaults = UserDefaults.standard
        let maxMemoryMB = defaults.integer(forKey: "MaxMemoryMB")
        let maxMemoryPolicy = defaults.string(forKey: "MaxMemoryPolicy") ?? "noeviction"
        
        var configContent = """
        # RedisMenu 自动生成的配置文件
        port \(port)
        dir "\(dataDir)"
        logfile "\(logPath)"
        daemonize no
        """
        
        // 支持 Redis 内存限制与淘汰策略
        if maxMemoryMB > 0 {
            configContent += "\nmaxmemory \(maxMemoryMB)mb\n"
            configContent += "maxmemory-policy \(maxMemoryPolicy)\n"
        }
        
        do {
            try configContent.write(toFile: configPath, atomically: true, encoding: .utf8)
            return configPath
        } catch {
            NSLog("生成 Redis 配置文件出错: \(error)")
            return ""
        }
    }
    
    /// 尝试通过 redis-cli 发送 shutdown 命令优雅停止
    private func tryGracefulShutdown() {
        guard let redisCliPath = findRedisCliBinary() else {
            return
        }
        
        let shutdownProcess = Process()
        shutdownProcess.executableURL = URL(fileURLWithPath: redisCliPath)
        shutdownProcess.arguments = ["-p", "\(port)", "shutdown"]
        
        do {
            try shutdownProcess.run()
            NSLog("已通过 redis-cli 向端口 \(port) 发送优雅停机指令")
        } catch {
            NSLog("发送优雅停机指令失败: \(error)")
        }
    }
    
    /// 检查指定端口是否已被占用
    private func isRedisAlreadyRunning() -> Bool {
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
            NSLog("检查端口占用失败: \(error)")
            return false
        }
    }
    
    /// 读取日志排查启动错误
    private func checkLogForErrors(logPath: String) {
        do {
            let logContent = try String(contentsOfFile: logPath, encoding: .utf8)
            let lines = logContent.components(separatedBy: .newlines).reversed()
            
            // 扫描最后 50 行日志查找错误提示
            for line in lines.prefix(50) {
                if line.contains("ERR") || line.contains("error") || line.contains("FATAL") {
                    NSLog("Redis 日志中发现错误: \(line)")
                    
                    if line.contains("Address already in use") || line.contains("port") {
                        displayAlert(title: "Redis 错误",
                                     message: "Redis 启动失败，端口已被占用。可能已有另一个实例正在运行。")
                    } else if line.contains("Permission denied") {
                        displayAlert(title: "Redis 错误",
                                     message: "Redis 启动失败，访问数据目录或日志目录权限不足。")
                    } else {
                        displayAlert(title: "Redis 错误",
                                     message: "Redis 启动失败。详情请查看日志文件：\n\(logPath)")
                    }
                    break
                }
            }
        } catch {
            NSLog("读取 Redis 日志失败: \(error)")
        }
    }
    
    /// 监控输出与错误流
    private func setupOutputMonitoring() {
        guard let outputPipe = standardOutput, let errorPipe = standardError else { return }
        
        DispatchQueue.global(qos: .background).async {
            let outputHandle = outputPipe.fileHandleForReading
            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        NSLog("Redis 输出: \(output)")
                    }
                }
            }
        }
        
        DispatchQueue.global(qos: .background).async {
            let errorHandle = errorPipe.fileHandleForReading
            errorHandle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let error = String(data: data, encoding: .utf8) {
                        NSLog("Redis 错误输出: \(error)")
                        
                        if error.contains("Address already in use") {
                            self?.displayAlert(title: "Redis 错误",
                                              message: "Redis 启动失败：端口已被占用")
                        }
                    }
                }
            }
        }
    }
    
    /// 显示统一的警告弹窗
    private func displayAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}
