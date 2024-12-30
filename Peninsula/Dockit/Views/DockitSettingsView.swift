import SwiftUI
import Combine

struct DockitSettingsView: View {
    @State private var hasAccessibility: Bool = false
    @State private var showingRestartAlert: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    
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
