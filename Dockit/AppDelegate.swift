import AppKit
import Cocoa
import LaunchAtLogin
import SwiftUI
import NotchNotification

class AppDelegate: NSObject, NSApplicationDelegate {
    var isFirstOpen = true
    var isLaunchedAtLogin = false
    var counter = 0

    var timer: Timer?

    private var dockitManager: DockitManager?
    private var settingsWindowController: NSWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.prohibited)
        
        // 初始化 DockitManager
        dockitManager = DockitManager.shared
        
        // 注册快捷键
        DockitShortcuts.register()
        
        // 创建设置菜单
        setupMenu()

        // 检查权限状态
        checkAccessibilityPermission()
    }

    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: ""))
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "inset.filled.trailinghalf.arrow.trailing.rectangle", accessibilityDescription: "Dockit")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
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
        }
        
        settingsWindowController?.showWindow(nil)
        if let window = settingsWindowController?.window {
            window.orderFrontRegardless()
            window.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        // 先取消所有窗口停靠
        DockitManager.shared.undockAllWindows(type: .quit)

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
}
