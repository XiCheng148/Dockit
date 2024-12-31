import SwiftUI
import Combine

struct DockitSettingsView: View {
    @State private var hasAccessibility: Bool = false
    @State private var showingRestartAlert: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    
    @ObservedObject private var manager = DockitManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("辅助功能权限")
                    .font(.system(size: 14))
                StatusIndicator(isEnabled: hasAccessibility)
                Spacer()
                if !hasAccessibility {
                    Button("请求权限") {
                        requestAccessibility()
                    }
                    .font(.system(size: 14))
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("启用窗口停靠", isOn: $manager.isEnabled)
                    .font(.system(size: 14))
            }
            .padding(.horizontal)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("高级设置")
                    .font(.system(size: 14, weight: .medium))
                
                HStack {
                    Text("露出像素")
                        .font(.system(size: 14))
                    Spacer()
                    TextField("", value: $manager.exposedPixels, formatter: NumberFormatter())
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .help("停靠时窗口露出的像素数")
                }
                
                HStack {
                    Text("触发区域宽度")
                        .font(.system(size: 14))
                    Spacer()
                    TextField("", value: $manager.triggerAreaWidth, formatter: NumberFormatter())
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .help("鼠标触发展开的区域宽度，越高越容易误触")
                }
                
                HStack {
                    Text("鼠标监听频率")
                        .font(.system(size: 14))
                    Spacer()
                    Picker("", selection: $manager.fps) {
                        Text("节能 (4fps)").tag(4.0)
                        Text("平衡 (10fps)").tag(10.0)
                        Text("流畅 (30fps)").tag(30.0)
                        Text("跟手 (60fps)").tag(60.0)
                        Text("丝滑 (120fps)").tag(120.0)
                    }
                    .frame(width: 120)
                    .help("更高的频率会更流畅但多的 cpu 占用")
                }
            }
            .padding(.horizontal)
        }
        .frame(width: 300)
        .onAppear {
            setupAccessibilityMonitoring()
        }
        .alert("需要重启应用", isPresented: $showingRestartAlert) {
            Button("稍后重启") {
                showingRestartAlert = false
            }
            Button("立即重启") {
                restartApp()
            }
        } message: {
            Text("已获得辅助功能权限，需要重启应用才能生效。")
        }
    }
    
    private func setupAccessibilityMonitoring() {
        // 检查初始状态
        hasAccessibility = AccessibilityHelper.shared.checkAccessibility()
        
        // 监听权限变化
        AccessibilityHelper.shared.accessibilityStatusPublisher
            .sink { newStatus in
                if newStatus && !hasAccessibility {
                    hasAccessibility = true
                    showingRestartAlert = true
                }
            }
            .store(in: &cancellables)
    }
    
    private func requestAccessibility() {
        AccessibilityHelper.shared.requestAccessibility()
    }
    
    private func restartApp() {
        let executablePath = Bundle.main.executablePath!
        let process = Process()
        process.launchPath = executablePath
        try? process.run()
        NSApp.terminate(nil)
    }
} 
