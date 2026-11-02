//
//  AppActivationHandler.swift
//  RedisMenu
//
//  Created by Mario Alberto Chávez on 31/03/25.
//

import Cocoa

class AppActivationHandler {
    static let shared = AppActivationHandler()
    
    private let appIdentifier: String
    
    private init() {
        self.appIdentifier = Bundle.main.bundleIdentifier ?? "com.maquina-app.RedisMenu"
    }
    
    /// 检查是否有其他实例正在运行并将其激活
    /// - Returns: 如果是首个实例返回 true，如果已有实例在运行则返回 false
    func checkAndActivateExistingInstance() -> Bool {
        // 注册接收现有实例的激活响应
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExistingInstanceResponse),
            name: NSNotification.Name("\(appIdentifier).AlreadyRunning"),
            object: nil
        )
        
        // 发送分布式通知，检查是否有现有实例响应
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("\(appIdentifier).ActivateApp"),
            object: appIdentifier,
            userInfo: nil,
            deliverImmediately: true
        )
        
        // 短暂等待现有实例的响应
        let date = Date()
        let runLoop = RunLoop.current
        while Date().timeIntervalSince(date) < 1.0 {
            if existingInstanceDetected {
                return false
            }
            runLoop.run(until: Date().addingTimeInterval(0.1))
        }
        
        return !existingInstanceDetected
    }
    
    private var existingInstanceDetected = false
    
    @objc private func handleExistingInstanceResponse(_ notification: Notification) {
        existingInstanceDetected = true
    }
}
