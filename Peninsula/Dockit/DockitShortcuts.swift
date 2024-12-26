import AppKit
import Foundation

class DockitShortcuts {
    static func register() {
        // 使用现有的快捷键系统注册新快捷键
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains([.command, .shift]) else { return }
            
            switch event.keyCode {
            case 123: // 左箭头
                DockitLogger.shared.logShortcut(.left)
                DockitManager.shared.dockActiveWindow(to: .left)
            case 124: // 右箭头
                DockitLogger.shared.logShortcut(.right)
                DockitManager.shared.dockActiveWindow(to: .right)
            case 4:  // H 键
                DockitLogger.shared.logUndockAllShortcut()
                DockitManager.shared.undockAllWindows()
            default:
                break
            }
        }
    }
} 
