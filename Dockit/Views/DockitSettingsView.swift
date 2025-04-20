import SwiftUI
import Combine
import KeyboardShortcuts
import LaunchAtLogin
import Defaults
import AppKit

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
    @State private var isInvalidInput: Bool = false
    
    var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }
    
    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Slider(value: Binding(
                    get: { value },
                    set: { newValue in
                        value = newValue
                        tempValue = numberFormatter.string(from: NSNumber(value: newValue)) ?? ""
                    }
                ), in: range)
                    .frame(width: 100)
                    .help("\(Int(range.lowerBound))～\(Int(range.upperBound))")
                
                TextField("", text: $tempValue)
                    .frame(width: 40)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .onAppear {
                        tempValue = numberFormatter.string(from: NSNumber(value: value)) ?? ""
                    }
                    .onChange(of: tempValue) { newValue in
                        // 检查输入是否为有效数字
                        if let numberValue = numberFormatter.number(from: newValue)?.doubleValue {
                            let clampedValue = min(max(numberValue, range.lowerBound), range.upperBound)
                            
                            // 如果输入值超出范围，显示警告状态
                            isInvalidInput = numberValue < range.lowerBound || numberValue > range.upperBound
                            
                            if clampedValue != value {
                                value = clampedValue
                                // 更新显示的值为实际应用的值
                                if isInvalidInput {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        tempValue = numberFormatter.string(from: NSNumber(value: clampedValue)) ?? ""
                                        isInvalidInput = false
                                    }
                                }
                            }
                        } else {
                            // 输入非数字时显示警告状态
                            isInvalidInput = true
                            // 如果输入非法，0.5秒后恢复显示当前值
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                tempValue = numberFormatter.string(from: NSNumber(value: value)) ?? ""
                                isInvalidInput = false
                            }
                        }
                    }
                    .foregroundColor(isInvalidInput ? .red : .primary)
                    .help("\(Int(range.lowerBound))～\(Int(range.upperBound))")
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
    
    @State private var expandModifiers: UInt = Defaults[.expandModifiers]
    @State private var collapseModifiers: UInt = Defaults[.collapseModifiers]
    @State private var lastCopyTime: Date? = nil // For debounce

    // Computed property to get version string
    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
        return "Version \(version) (Build \(build))"
    }
    
    var body: some View {
        Form {
            Section(header: Text("基础设置").font(.headline)) {
                HStack(spacing: 4) {
                    Text("辅助功能权限")
                    HelpIcon(text: "需要此权限来管理窗口位置")
                    Circle()
                        .fill(hasAccessibility ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
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

            Section(header: Text("预览设置").font(.headline)) {
                LabeledContent {
                    Toggle("", isOn: $manager.showPreview)
                        .toggleStyle(.switch)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                } label: {
                    HStack(spacing: 4) {
                        Text("显示停靠预览")
                        HelpIcon(text: "显示窗口停靠时的动画预览")
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
                            (4, "节能"),
                            (10, "平衡"),
                            (30, "流畅"),
                            (60, "丝滑")
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
                
                LabeledContent {
                    Picker("", selection: $manager.notchStyle) {
                        Text("自动").tag("auto")
                        Text("刘海").tag("notch")
                        Text("浮动").tag("floating")
                    }
                    .pickerStyle(.segmented)
                } label: {
                    HStack(spacing: 4) {
                        Text("通知样式")
                        HelpIcon(text: "选择通知在屏幕上的显示样式")
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
                
                ModifierKeysSelector(
                    title: "展开触发键",
                    selection: $expandModifiers
                )
                .onChange(of: expandModifiers) { newValue in
                    Defaults[.expandModifiers] = newValue
                }
                .help("按住此键并移动鼠标到屏幕边缘时展开窗口")
                
                ModifierKeysSelector(
                    title: "收起触发键",
                    selection: $collapseModifiers
                )
                .onChange(of: collapseModifiers) { newValue in
                    Defaults[.collapseModifiers] = newValue
                }
                .help("按住此键并移动鼠标离开窗口时收起窗口")
            }

        }
        .formStyle(.grouped)
        .background(.background)
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
        // Version display and copy functionality
        Text(appVersionString)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
            .onTapGesture {
                copyVersionToClipboard()
            }
            .onHover { hovering in // Add hover effect
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
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
    
    private func copyVersionToClipboard() {
        let now = Date()
        // Debounce: Allow copy only if 1 second has passed since the last copy
        if let lastTime = lastCopyTime, now.timeIntervalSince(lastTime) < 1.0 {
            DockitLogger.shared.logInfo("Debounced: Too soon to copy version again.")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(appVersionString, forType: .string) {
            lastCopyTime = now // Update last copy time
            NotificationHelper.show(type: .success, title: "版本号已复制")
            DockitLogger.shared.logInfo("Version copied: \(appVersionString)")
        } else {
            DockitLogger.shared.logError("Failed to copy version to clipboard.")
            // Optionally show an error notification
            // NotificationHelper.show(type: .error, title: "复制失败")
        }
    }
} 

#Preview {
    DockitSettingsView()
}
