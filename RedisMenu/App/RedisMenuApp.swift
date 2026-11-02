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
        // 使用文件锁方式检查是否有另一个实例正在运行
        if !SingleInstanceManager.shared.acquireLock() {
            // 已有实例在运行，终止当前实例
            print("RedisMenu 的另一个实例已在运行中，程序退出。")
            NSApp.terminate(nil)
        }
    }

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}
