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
        // 删除左侧停靠按下快捷键时的预览
        KeyboardShortcuts.onKeyDown(for: .dockLeft) {
            DockitLogger.shared.logShortcut(.left)
        }
        
        // 松开快捷键时先执行实际的窗口操作，然后再执行预览动画
        KeyboardShortcuts.onKeyUp(for: .dockLeft) {
            // 取消任何当前正在进行的动画和操作
            DockPreviewController.shared.cancelCurrentAnimation()
            
            // 获取当前活动窗口
            if let app = NSWorkspace.shared.frontmostApplication {
                let axApp = AxApplication(element: AXUIElementCreateApplication(app.processIdentifier))
                if let window = try? axApp.focusedWindow(),
                   let initialFrame = try? window.frame(),
                   let mainScreen = NSScreen.main {
                    
                    // 1. 先执行实际的窗口设置位置操作
                    DockitManager.shared.dockActiveWindow(to: .left)
                    
                    // 2. 获取设置后的位置并执行预览动画
                    if let finalFrame = try? window.frame() {
                        DockPreviewController.shared.showAnimatedTransition(initialFrame: initialFrame, targetFrame: finalFrame)
                    }
                } else {
                    // 如果无法获取窗口信息，直接执行停靠操作
                    DockitManager.shared.dockActiveWindow(to: .left)
                }
            } else {
                DockitManager.shared.dockActiveWindow(to: .left)
            }
        }
        
        // 删除右侧停靠按下快捷键时的预览
        KeyboardShortcuts.onKeyDown(for: .dockRight) {
            DockitLogger.shared.logShortcut(.right)
        }
        
        // 松开快捷键时先执行实际的窗口操作，然后再执行预览动画
        KeyboardShortcuts.onKeyUp(for: .dockRight) {
            // 取消任何当前正在进行的动画和操作
            DockPreviewController.shared.cancelCurrentAnimation()
            
            // 获取当前活动窗口
            if let app = NSWorkspace.shared.frontmostApplication {
                let axApp = AxApplication(element: AXUIElementCreateApplication(app.processIdentifier))
                if let window = try? axApp.focusedWindow(),
                   let initialFrame = try? window.frame(),
                   let mainScreen = NSScreen.main {
                    
                    // 1. 先执行实际的窗口设置位置操作
                    DockitManager.shared.dockActiveWindow(to: .right)
                    
                    // 2. 获取设置后的位置并执行预览动画
                    if let finalFrame = try? window.frame() {
                        DockPreviewController.shared.showAnimatedTransition(initialFrame: initialFrame, targetFrame: finalFrame)
                    }
                } else {
                    // 如果无法获取窗口信息，直接执行停靠操作
                    DockitManager.shared.dockActiveWindow(to: .right)
                }
            } else {
                DockitManager.shared.dockActiveWindow(to: .right)
            }
        }
        
        // 注册取消所有停靠快捷键
        KeyboardShortcuts.onKeyDown(for: .undockAll) {
            DockitManager.shared.undockAllWindows()
        }
    }
} 
