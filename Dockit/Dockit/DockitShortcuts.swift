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
            DockitManager.shared.dockActiveWindow(to: .left)
        }
        
        // 注册右侧停靠快捷键
        KeyboardShortcuts.onKeyDown(for: .dockRight) {
            DockitLogger.shared.logShortcut(.right) 
            DockitManager.shared.dockActiveWindow(to: .right)
        }
        
        // 注册取消所有停靠快捷键
        KeyboardShortcuts.onKeyDown(for: .undockAll) {
            DockitManager.shared.undockAllWindows()
        }
    }
} 
