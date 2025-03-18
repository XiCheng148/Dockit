import AppKit
import Foundation

class SpaceMonitorService {
    static let shared = SpaceMonitorService()
    
    private var workspaceNotificationObserver: NSObjectProtocol?
    
    // 空间切换事件回调
    var onSpaceChanged: (() -> Void)?
    
    private init() {
        // 添加工作区切换监听
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onSpaceChanged?()
        }
    }
    
    func isWindowVisibleOnScreen(_ window: AxWindow) -> Bool {
        guard let frame = try? window.frame() else {
            DockitLogger.shared.logError("无法获取窗口框架")
            return false
        }
        
        let screens = NSScreen.screens
        
        for screen in screens {
            if screen.frame.intersects(frame) {
                if let windowId = try? window.cgWindowId(),
                   let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[CFString: Any]] {
                    let isVisible = windowList.contains { dict in
                        if let id = dict[kCGWindowNumber] as? CGWindowID {
                            return id == windowId
                        }
                        return false
                    }
                    if !isVisible {
                        DockitLogger.shared.logInfo("窗口不在当前工作区")
                    }
                    return isVisible
                } else {
                    DockitLogger.shared.logError("无法获取窗口ID或窗口列表")
                }
            }
        }
        
        return false
    }
    
    deinit {
        if let observer = workspaceNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
} 
