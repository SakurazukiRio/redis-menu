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
    
    @Published var redisStatus: String = "启动中..."
    
    // 监听 Redis 运行状态变更
    private var redisStatusObserver: NSObjectProtocol?
    
    // 应用唯一标识符
    private let appIdentifier = "com.maquina-app.RedisMenu"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 检查是否有另一个实例已经在运行
        if !ensureSingleInstance() {
            NSApp.terminate(nil)
            return
        }
        
        print("应用程序启动完成")
        // 设置菜单栏状态图标与菜单
        setupMenuBar()
        print("菜单栏配置完成")
        
        // 若开启了自动启动，则启动 Redis
        if UserDefaults.standard.bool(forKey: "AutoStartRedis") {
            print("已开启自动启动，正在启动 Redis...")
            startRedis()
        } else {
            redisStatus = "已停止"
            updateStatusDisplay()
        }
        
        // 注册 Redis 状态变更观察者
        redisStatusObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RedisStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isRunning = notification.object as? Bool {
                self?.redisStatus = isRunning ? "运行中" : "已停止"
                self?.updateStatusDisplay()
            }
        }
        
        // 注册应用被重复调起时的激活通知
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleAppActivationRequest),
            name: NSNotification.Name("\(appIdentifier).ActivateApp"),
            object: nil
        )
    }
    
    /// 确保单实例运行
    private func ensureSingleInstance() -> Bool {
        // 向其他潜在实例广播激活通知
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("\(appIdentifier).ActivateApp"),
            object: Bundle.main.bundleIdentifier,
            userInfo: nil,
            deliverImmediately: true
        )
        
        // 稍作等待以让已有实例响应
        Thread.sleep(forTimeInterval: 0.5)
        return true
    }
    
    @objc private func handleAppActivationRequest(notification: NSNotification) {
        // 判断通知是否来自其他尝试启动的实例
        if notification.object as? String != Bundle.main.bundleIdentifier {
            // 将应用置于前台激活
            NSApp.activate(ignoringOtherApps: true)
            
            // 显示偏好设置窗口
            if let window = preferencesWindow {
                window.makeKeyAndOrderFront(nil)
            } else {
                openPreferences()
            }
            
            // 发送通知告知对方已有实例正在运行
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

    /// 构建顶部菜单栏
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
                print("已加载状态栏图标: \(String(describing: button.image))")
            } else {
                print("加载 MenuBarIcon 失败，使用文本兜底")
                button.title = "R"
            }
        }

        menu = NSMenu()
        menu?.addItem(NSMenuItem(title: "Redis 状态: \(redisStatus)", action: nil, keyEquivalent: ""))
        menu?.addItem(NSMenuItem.separator())
        
        let startStopItem = NSMenuItem(title: "启动 Redis", action: #selector(toggleRedis), keyEquivalent: "s")
        startStopItem.target = self
        menu?.addItem(startStopItem)

        menu?.addItem(NSMenuItem.separator())

        let openData = NSMenuItem(title: "打开数据目录", action: #selector(openDataFolder), keyEquivalent: "d")
        openData.target = self
        menu?.addItem(openData)

        let openLog = NSMenuItem(title: "打开日志目录", action: #selector(openLogFolder), keyEquivalent: "l")
        openLog.target = self
        menu?.addItem(openLog)

        menu?.addItem(NSMenuItem.separator())

        let preferencesItem = NSMenuItem(title: "偏好设置...", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu?.addItem(preferencesItem)

        menu?.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

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

    /// 更新菜单栏显示信息
    func updateStatusDisplay() {
        // 更新包含端口号的状态项
        menu?.item(at: 0)?.title = "Redis 状态: \(redisStatus) (端口: \(RedisService.shared.port))"
        
        // 更新启动/停止按钮文案
        if let startStopItem = menu?.item(at: 2) {
            startStopItem.title = RedisService.shared.isRunning ? "停止 Redis" : "启动 Redis"
        }
        
        // 刷新状态栏图标
        if let button = statusItem?.button {
            let icon = NSImage(named: "MenuBarIcon")
            if let icon = icon {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            }
        }
    }

    /// 打开数据文件夹
    @objc func openDataFolder() {
        let dataDir = UserDefaults.standard.string(forKey: "RedisDataDir") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/redis/data"
        NSWorkspace.shared.open(URL(fileURLWithPath: dataDir))
    }

    /// 打开日志文件夹
    @objc func openLogFolder() {
        let logPath = UserDefaults.standard.string(forKey: "RedisLogPath") ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/state/redis/logs/redis.log"
        let logDir = URL(fileURLWithPath: logPath).deletingLastPathComponent()
        NSWorkspace.shared.open(logDir)
    }

    /// 打开偏好设置窗口
    @objc func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            preferencesWindow?.center()
            preferencesWindow?.title = "Redis 偏好设置"
            preferencesWindow?.contentView = NSHostingView(rootView: PreferencesView())
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// 应用即将退出时拦截
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if RedisService.shared.isRunning {
            print("应用程序正在退出，等待 Redis 停止服务...")
            
            // 异步关闭 Redis
            RedisService.shared.stopRedis {
                print("Redis 已成功停止，继续退出应用程序")
                DispatchQueue.main.async {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            }
            
            // 稍后退出
            return .terminateLater
        } else {
            return .terminateNow
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        RedisService.shared.stopRedis()
    }
}
