import AppKit
import Cocoa
import LaunchAtLogin
import SwiftUI

@main
struct DockitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Dockit",image:"MenuBarIcon") {
            #if DEBUG
                Text("DEV BUILD: \(Bundle.main.appVersion ?? "Unknown") (\(Bundle.main.appBuild ?? 0))")
                    .font(.system(size: 11, weight: .semibold))
            #endif
            
            Button("设置") {
                appDelegate.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button("退出") {
                appDelegate.quit()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var isFirstOpen = true
    var isLaunchedAtLogin = false
    var counter = 0

    var timer: Timer?

    private var dockitManager: DockitManager?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.prohibited)
        
        // 初始化后台工作
        BackgroundWork.start()
        _ = Applications.shared
        
        // 初始化 DockitManager
        dockitManager = DockitManager.shared
        
        // 注册快捷键
        DockitShortcuts.register()

        // 检查权限状态
        checkAccessibilityPermission()
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Dockit 设置"
            window.center()
            window.isMovableByWindowBackground = true
            
            let hostingView = NSHostingView(rootView: DockitSettingsView())
            window.contentView = hostingView
            
            let windowController = NSWindowController(window: window)
            settingsWindowController = windowController
            
            window.isReleasedWhenClosed = false
            window.delegate = self // Set the delegate
        }
        
        // Temporarily change activation policy
        NSApp.setActivationPolicy(.accessory)
        
        settingsWindowController?.showWindow(nil)
        if let window = settingsWindowController?.window {
            window.orderFrontRegardless()
            window.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true) // Removed to prevent Dock icon appearance
    }

    @objc func quit() {
        // 先取消所有窗口停靠
        DockitManager.shared.undockAllWindows(type: .normal)

        NotificationHelper.show(
            type: .success,
            title: "退出前清理停靠窗口"
        )
        
        // 延迟一小段时间后退出应用,确保取消停靠动作完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func checkAccessibilityPermission() {
        if !AccessibilityHelper.shared.checkAccessibility() {
            // 自动打开设置窗口
            openSettings()
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // Revert activation policy when settings window closes
        if let window = notification.object as? NSWindow, window == settingsWindowController?.window {
            NSApp.setActivationPolicy(.prohibited)
        }
    }
}
