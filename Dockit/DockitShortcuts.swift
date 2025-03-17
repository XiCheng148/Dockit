import AppKit
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let dockLeft = Self("dockLeft", default: .init(.leftArrow, modifiers: [.command, .shift]))
    static let dockRight = Self("dockRight", default: .init(.rightArrow, modifiers: [.command, .shift])) 
    static let undockAll = Self("undockAll", default: .init(.h, modifiers: [.command, .shift]))
}

class DockitShortcuts {
    static func register() {
        // 注册左侧停靠快捷键
        KeyboardShortcuts.onKeyDown(for: .dockLeft) {
            DockitLogger.shared.logShortcut(.left)
            
            // 先检查窗口是否在主屏幕上
            if !DockitManager.shared.isActiveWindowOnMainScreen() {
                NotificationHelper.show(
                    type: .warning,
                    title: "无法停靠窗口",
                    description: "当前版本仅支持在主屏幕上停靠窗口"
                )
                return
            }
            
            // 获取当前活动窗口并显示预览
            if let app = NSWorkspace.shared.frontmostApplication {
                let axApp = AxApplication(element: AXUIElementCreateApplication(app.processIdentifier))
                if let window = try? axApp.focusedWindow(),
                   let frame = try? window.frame() {
                    DockPreviewController.shared.showPreview(for: .left, window: frame)
                }
            }
        }
        KeyboardShortcuts.onKeyUp(for: .dockLeft) {
            DockitManager.shared.dockActiveWindow(to: .left)
        }
        
        // 注册右侧停靠快捷键
        KeyboardShortcuts.onKeyDown(for: .dockRight) {
            DockitLogger.shared.logShortcut(.right)
            
            // 先检查窗口是否在主屏幕上
            if !DockitManager.shared.isActiveWindowOnMainScreen() {
                NotificationHelper.show(
                    type: .warning,
                    title: "无法停靠窗口",
                    description: "当前版本仅支持在主屏幕上停靠窗口"
                )
                return
            }
            
            // 获取当前活动窗口并显示预览
            if let app = NSWorkspace.shared.frontmostApplication {
                let axApp = AxApplication(element: AXUIElementCreateApplication(app.processIdentifier))
                if let window = try? axApp.focusedWindow(),
                   let frame = try? window.frame() {
                    DockPreviewController.shared.showPreview(for: .right, window: frame)
                }
            }
        }
        KeyboardShortcuts.onKeyUp(for: .dockRight) {
            DockitManager.shared.dockActiveWindow(to: .right)
        }
        
        // 注册取消所有停靠快捷键
        KeyboardShortcuts.onKeyDown(for: .undockAll) {
            DockitManager.shared.undockAllWindows()
        }
    }
} 
