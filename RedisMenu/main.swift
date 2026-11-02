//
//  main.swift
//  RedisMenu
//
//  Created by Mario Alberto Chávez on 31/03/25.
//

import Cocoa

// 检查是否能够获取单实例文件锁
let canAcquireLock = SingleInstanceManager.shared.acquireLock()

// 检查是否有另一个实例在运行并尝试激活它
let isFirstInstance = AppActivationHandler.shared.checkAndActivateExistingInstance()

if canAcquireLock && isFirstInstance {
    // 当前为唯一实例，继续正常启动流程
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    
    // 应用程序启动入口
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    
    // 应用程序退出时释放文件锁
    SingleInstanceManager.shared.releaseLock()
} else {
    // 另一个实例已经在运行中，直接退出
    print("RedisMenu 的另一个实例已在运行中，程序退出。")
    exit(0)
}
