import SwiftUI
import Combine
import KeyboardShortcuts
import LaunchAtLogin

struct HelpIcon: View {
    let text: String
    @State private var showingHelp = false
    
    var body: some View {
        Image(systemName: "questionmark.circle")
            .foregroundColor(.secondary)
            .onTapGesture {
                showingHelp.toggle()
            }
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .popover(isPresented: $showingHelp, arrowEdge: .trailing) {
                Text(text)
                    .font(.system(size: 12))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .frame(minWidth: 100, maxWidth: 250, alignment: .leading)
            }
    }
}

struct SliderWithTextField: View {
    let title: String
    let helpText: String
    let range: ClosedRange<Double>
    @Binding var value: Double
    
    @State private var tempValue: String = ""
    
    var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }
    
    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Slider(value: $value, in: range)
                    .frame(width: 100)
                    .help("\(Int(range.lowerBound))～\(Int(range.upperBound))")
                
                TextField("", text: $tempValue)
                    .frame(width: 40)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .onAppear {
                        tempValue = numberFormatter.string(from: NSNumber(value: value)) ?? ""
                    }
                    .onChange(of: value) { newValue in
                        tempValue = numberFormatter.string(from: NSNumber(value: newValue)) ?? ""
                    }
                    .onChange(of: tempValue) { newValue in
                        if let numberValue = numberFormatter.number(from: newValue)?.doubleValue {
                            value = min(max(numberValue, range.lowerBound), range.upperBound)
                        }
                    }
                    .onSubmit {
                        tempValue = numberFormatter.string(from: NSNumber(value: value)) ?? ""
                    }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                HelpIcon(text: helpText)
            }
        }
    }
}

struct DockitSettingsView: View {
    @State private var hasAccessibility: Bool = false
    @State private var showingRestartAlert: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    
    @ObservedObject private var manager = DockitManager.shared
    
    var body: some View {
        Form {
            Section {
                HStack(spacing: 4) {
                    Text("辅助功能权限")
                    HelpIcon(text: "需要此权限来管理窗口位置")
                    StatusIndicator(isEnabled: hasAccessibility)
                    Spacer()
                    if !hasAccessibility {
                        Button("授权") {
                            requestAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
            }
            
            Section {
                HStack(spacing: 4) {
                    Toggle("启用停靠", isOn: $manager.isEnabled)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }
                
                HStack(spacing: 4) {
                    LaunchAtLogin.Toggle("开机启动")
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }
            }
            
            Section(header: Text("高级设置").font(.headline)) {
                SliderWithTextField(
                    title: "露出宽度",
                    helpText: "停靠时窗口露出的宽度",
                    range: 5...20,
                    value: $manager.exposedPixels
                )
                
                SliderWithTextField(
                    title: "触发区域",
                    helpText: "鼠标触发展开的区域，数值越大越容易触发",
                    range: 2...20,
                    value: $manager.triggerAreaWidth
                )
                
                LabeledContent {
                    Picker("", selection: $manager.fps) {
                        ForEach([
                            (4.0, "节能"),
                            (10.0, "平衡"),
                            (30.0, "流畅"),
                            (60.0, "丝滑")
                        ], id: \.0) { fps, label in
                            Text(label)
                                .tag(fps)
                        }
                    }
                    .pickerStyle(.segmented)
                } label: {
                    HStack(spacing: 4) {
                        Text("响应速度")
                        HelpIcon(text: "更快的响应速度会增加 CPU 占用")
                    }
                }
            }
            
            Section(header: Text("快捷键").font(.headline)) {
                HStack {
                    Text("左侧停靠")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .dockLeft)
                        .onAppear {
                            activateWindow()
                        }
                }
                .help("将当前窗口停靠到左侧")
                
                HStack {
                    Text("右侧停靠")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .dockRight)
                        .onAppear {
                            activateWindow()
                        }
                }
                .help("将当前窗口停靠到右侧")
                
                HStack {
                    Text("取消停靠")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .undockAll)
                        .onAppear {
                            activateWindow()
                        }
                }
                .help("取消所有已停靠的窗口")
            }
        }
        .formStyle(.grouped)
        .fixedSize()
        .onAppear {
            setupAccessibilityMonitoring()
            activateWindow()
            NSApp.setActivationPolicy(.regular)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.prohibited)
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
    
    private func activateWindow() {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.contentView?.subviews.contains(where: { $0 is NSHostingView<DockitSettingsView> }) ?? false }) {
                window.level = .floating
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
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
