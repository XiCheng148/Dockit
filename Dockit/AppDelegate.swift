import AppKit
import Cocoa
import LaunchAtLogin
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var isFirstOpen = true
    var isLaunchedAtLogin = false
    var counter = 0

    var timer: Timer?

    private var dockitManager: DockitManager?
    private var settingsWindowController: NSWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // 添加关闭窗口的快捷键支持
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) {
                if event.charactersIgnoringModifiers == "w" {
                    if let window = NSApp.keyWindow {
                        window.close()
                        return nil
                    }
                }
                if event.charactersIgnoringModifiers == "q" {
                    NSApplication.shared.terminate(nil)
                    return nil
                }
            }
            return event
        }
        
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
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "⚓️"
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
            
            // 添加关闭窗口的代理
            window.delegate = self
            
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

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}
