//
//  SingleInstanceManager.swift
//  RedisMenu
//
//  Created by Mario Alberto Chávez on 31/03/25.
//

import Foundation
import Darwin

class SingleInstanceManager {
    static let shared = SingleInstanceManager()
    
    private let lockFilePath: String
    private var lockFileDescriptor: Int32 = -1
    
    private init() {
        // 在 Application Support 目录中创建锁文件
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appBundleID = Bundle.main.bundleIdentifier ?? "com.maquina-app.RedisMenu"
        let appDirectory = appSupport.appendingPathComponent(appBundleID)
        
        // 若目录不存在则创建
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        // 设置锁文件路径
        lockFilePath = appDirectory.appendingPathComponent("app.lock").path
    }
    
    /// 尝试获取文件锁以确保只有一个实例在运行
    /// - Returns: 若为唯一实例返回 true，否则返回 false
    func acquireLock() -> Bool {
        // 使用 O_CREAT | O_WRONLY | O_EXLOCK | O_NONBLOCK 打开文件
        // O_EXLOCK 用于获取独占排他锁
        // O_NONBLOCK 为非阻塞模式（若无法获取锁则立即返回）
        lockFileDescriptor = open(lockFilePath, O_CREAT | O_WRONLY | O_EXLOCK | O_NONBLOCK, 0o644)
        
        if lockFileDescriptor == -1 {
            print("无法获取文件锁，可能已有另一个实例正在运行。")
            return false
        }
        
        // 将当前进程 PID 写入锁文件
        let pid = ProcessInfo.processInfo.processIdentifier
        let pidString = "\(pid)\n"
        
        if let data = pidString.data(using: .utf8) {
            _ = data.withUnsafeBytes { buffer in
                write(lockFileDescriptor, buffer.baseAddress, buffer.count)
            }
        }
        
        return true
    }
    
    /// 当应用程序退出时释放文件锁
    func releaseLock() {
        if lockFileDescriptor != -1 {
            close(lockFileDescriptor)
            lockFileDescriptor = -1
        }
    }
}
