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
    @AppStorage("RedisServerPath") private var customServerPath: String = ""
    @AppStorage("AutoStartRedis") private var autoStartRedis: Bool = true
    @AppStorage("LaunchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("RedisPort") private var redisPort: Int = 6379
    @AppStorage("MaxMemoryPolicy") private var maxMemoryPolicy: String = "noeviction"
    @AppStorage("MaxMemoryMB") private var maxMemoryMB: Int = 0 // 0 表示不限制
    
    @State private var showDataDirPicker = false
    @State private var showLogPathPicker = false
    @State private var showServerPicker = false
    @State private var restartRequired = false
    @State private var selectedTab = 0
    @State private var redisVersion: String = ""
    
    @ObservedObject private var redisService = RedisService.shared
    
    // Redis 内存淘汰策略选项（包含 Redis 8 支持的策略）
    private let memoryPolicyOptions = [
        "noeviction",     // 不淘汰，内存超限时写操作返回错误
        "allkeys-lru",    // 在所有键中按最近最少使用（LRU）淘汰
        "volatile-lru",   // 在带过期时间的键中按 LRU 淘汰
        "allkeys-lfu",    // 在所有键中按最不经常使用（LFU）淘汰
        "volatile-lfu",   // 在带过期时间的键中按 LFU 淘汰
        "allkeys-random", // 在所有键中随机淘汰
        "volatile-random",// 在带过期时间的键中随机淘汰
        "volatile-ttl"    // 优先淘汰剩余存活时间（TTL）最短的键
    ]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 基本设置选项卡
            settingsView
                .tabItem {
                    Label("基本设置", systemImage: "gear")
                }
                .tag(0)
            
            // 高级设置选项卡
            advancedView
                .tabItem {
                    Label("高级设置", systemImage: "gearshape.2")
                }
                .tag(1)
            
            // 关于选项卡
            aboutView
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(2)
        }
        .frame(width: 480)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            redisService.port = redisPort
            redisVersion = redisService.getRedisVersion()
            
            let storedValue = UserDefaults.standard.bool(forKey: "AutoStartRedis")
            if autoStartRedis != storedValue {
                autoStartRedis = storedValue
            }
            print("当前自启动设置: \(autoStartRedis)")
        }
    }
    
    // 基本设置页面内容
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle("应用启动时自动启动 Redis", isOn: $autoStartRedis)
                .onChange(of: autoStartRedis) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "AutoStartRedis")
                    UserDefaults.standard.synchronize()
                    print("自动启动设置更改为: \(newValue)")
                }
            
            Toggle("登录系统时自动启动应用 (开机自启)", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
            
            Divider()
            
            // 端口配置
            HStack {
                Text("Redis 端口:")
                Spacer()
                TextField("", value: $redisPort, formatter: NumberFormatter())
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
            }
            .onChange(of: redisPort) { _, _ in
                restartRequired = redisService.isRunning
            }
            
            // Redis 可执行文件路径
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Redis 核心路径:")
                    Spacer()
                    TextField("自动检测 (默认)", text: $customServerPath)
                        .frame(minWidth: 200)
                    Button("选择...") {
                        showServerPicker = true
                    }
                    .sheet(isPresented: $showServerPicker) {
                        BinaryPickerView(selectedPath: $customServerPath, title: "选择 redis-server 可执行文件")
                    }
                }
                HStack {
                    Text("已生效路径: \(redisService.findRedisServerBinary() ?? "未检测到")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("版本: \(redisVersion)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .onChange(of: customServerPath) { _, _ in
                redisVersion = redisService.getRedisVersion()
                restartRequired = redisService.isRunning
            }
            
            // 数据目录
            HStack {
                Text("数据存储目录:")
                Spacer()
                TextField("", text: $dataDir)
                    .frame(minWidth: 200)
                Button("浏览...") {
                    showDataDirPicker = true
                }
                .sheet(isPresented: $showDataDirPicker) {
                    DirectoryPickerView(selectedPath: $dataDir, title: "选择 Redis 数据存储目录")
                }
            }
            .onChange(of: dataDir) { _, _ in
                restartRequired = redisService.isRunning
            }
            
            // 日志路径
            HStack {
                Text("日志文件路径:")
                Spacer()
                TextField("", text: $logPath)
                    .frame(minWidth: 200)
                Button("浏览...") {
                    showLogPathPicker = true
                }
                .sheet(isPresented: $showLogPathPicker) {
                    FilePickerView(selectedPath: $logPath, title: "选择 Redis 日志保存文件")
                }
            }
            .onChange(of: logPath) { _, _ in
                restartRequired = redisService.isRunning
            }
            
            // 重启提示横幅
            if restartRequired {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("配置已修改，需要重启 Redis 生效")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("立即重启 Redis") {
                        restartRedis()
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
            
            Divider()
            
            // 运行状态与启停控制
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(redisService.isRunning ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text("Redis 状态: \(redisService.isRunning ? "运行中" : "已停止")")
                        .font(.headline)
                        .foregroundColor(redisService.isRunning ? .green : .red)
                }
                Spacer()
                Button(redisService.isRunning ? "停止 Redis" : "启动 Redis") {
                    if redisService.isRunning {
                        redisService.stopRedis()
                    } else {
                        redisService.startRedis()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding()
    }
    
    // 高级设置页面内容
    private var advancedView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 最大内存设置
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("最大内存限制 (MB):")
                    Spacer()
                    TextField("", value: $maxMemoryMB, formatter: NumberFormatter())
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                }
                Text("设为 0 表示不限制最大内存使用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onChange(of: maxMemoryMB) { _, _ in
                restartRequired = redisService.isRunning
            }
            
            // 内存淘汰策略选择
            HStack {
                Text("内存淘汰策略:")
                Spacer()
                Picker("", selection: $maxMemoryPolicy) {
                    ForEach(memoryPolicyOptions, id: \.self) { policy in
                        Text(policy).tag(policy)
                    }
                }
                .frame(width: 180)
            }
            .onChange(of: maxMemoryPolicy) { _, _ in
                restartRequired = redisService.isRunning
            }
            
            // 选中策略的详细解释
            Group {
                switch maxMemoryPolicy {
                case "noeviction":
                    explanationText("达到内存上限时不淘汰任何键，对所有写入操作返回错误。（默认策略）")
                case "allkeys-lru":
                    explanationText("在所有键中淘汰最近最少使用的键（LRU 算法）。")
                case "volatile-lru":
                    explanationText("仅在设置了过期时间的键中淘汰最近最少使用的键（LRU 算法）。")
                case "allkeys-lfu":
                    explanationText("在所有键中淘汰最不经常使用的键（LFU 算法，Redis 8 推荐）。")
                case "volatile-lfu":
                    explanationText("仅在设置了过期时间的键中淘汰最不经常使用的键（LFU 算法，Redis 8 推荐）。")
                case "allkeys-random":
                    explanationText("在所有键中随机挑选键淘汰以释放内存。")
                case "volatile-random":
                    explanationText("仅在设置了过期时间的键中随机挑选键淘汰。")
                case "volatile-ttl":
                    explanationText("仅在设置了过期时间的键中优先淘汰存活剩余时间（TTL）最短的键。")
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
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
    }
    
    // 关于页面内容
    private var aboutView: some View {
        VStack(spacing: 16) {
            Image("CompanyLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .padding(.top, 10)
            
            Text("RedisMenu")
                .font(.system(size: 22, weight: .bold))
            
            Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (支持 Redis 8 最新版)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("当前 Redis 内核版本: \(redisVersion)")
                    .font(.footnote)
                    .foregroundColor(.blue)
                
                Text("支持 Redis 8.x / 7.x 及本地安装环境")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text("Maquina App")
                .font(.headline)
                .padding(.top, 6)
            
            Link("https://maquina.app", destination: URL(string: "https://maquina.app")!)
                .font(.subheadline)
                .foregroundColor(.blue)
            
            Text("© \(Calendar.current.component(.year, from: Date())) Maquina App. 保留所有权利。")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 6)
            
            VStack(spacing: 2) {
                Text("Redis 及 Redis 徽标是 Redis Ltd. 的注册商标。")
                Text("本工具为开源独立管理菜单栏应用，非 Redis Ltd. 官方出品。")
            }
            .font(.caption2)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 340)
            .padding(.top, 4)
            
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
            print("设置开机启动失败: \(error)")
        }
        #endif
    }
    
    private func restartRedis() {
        if redisService.isRunning {
            redisService.stopRedis()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                redisService.startRedis()
                restartRequired = false
            }
        }
    }
}

// 目录选择器弹窗视图
struct DirectoryPickerView: View {
    @Binding var selectedPath: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            
            Button("选择目录") {
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
            
            Button("取消") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 150)
    }
}

// 文件选择器弹窗视图（日志文件保存选择）
struct FilePickerView: View {
    @Binding var selectedPath: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            
            Button("选择文件") {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [UTType.log]
                panel.nameFieldStringValue = "redis.log"
                
                if panel.runModal() == .OK {
                    selectedPath = panel.url?.path ?? selectedPath
                }
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            
            Button("取消") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 150)
    }
}

// 二进制执行文件选择器视图
struct BinaryPickerView: View {
    @Binding var selectedPath: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            
            Button("选择 redis-server 文件") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.resolvesAliases = true
                
                if panel.runModal() == .OK {
                    selectedPath = panel.url?.path ?? selectedPath
                }
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            
            Button("取消") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(width: 320, height: 160)
    }
}
