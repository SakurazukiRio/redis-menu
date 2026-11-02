//
//  LoggingService.swift
//  RedisMenu
//
//  Created by Mario Alberto Chávez on 31/03/25.
//

import Foundation

class LoggingService {
    static let shared = LoggingService()
    
    private let logFile: URL
    private let dateFormatter: DateFormatter
    
    init() {
        // 设置日志时间戳格式化器
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // 创建用于存储日志的 Application Support 目录
        let fileManager = FileManager.default
        var appSupportDir = try! fileManager.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        
        appSupportDir = appSupportDir.appendingPathComponent("RedisMenu", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try! fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        // 设置日志文件路径
        logFile = appSupportDir.appendingPathComponent("redismenu.log")
        
        // 若日志文件不存在则初始化创建
        if !fileManager.fileExists(atPath: logFile.path) {
            fileManager.createFile(atPath: logFile.path, contents: nil, attributes: nil)
        }
        
        // 记录应用启动日志
        log("RedisMenu 已启动")
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        
        // 输出到控制台
        print(logMessage, terminator: "")
        
        // 写入到日志文件
        if let data = logMessage.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
    }
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
}

// 便捷日志输出函数
func logDebug(_ message: String) {
    LoggingService.shared.log(message, level: .debug)
}

func logInfo(_ message: String) {
    LoggingService.shared.log(message, level: .info)
}

func logWarning(_ message: String) {
    LoggingService.shared.log(message, level: .warning)
}

func logError(_ message: String) {
    LoggingService.shared.log(message, level: .error)
}
