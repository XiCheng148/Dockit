import AppKit
import Foundation

class WindowDockingService {
    static let shared = WindowDockingService()
    
    private let prefsManager = PreferencesManager.shared
    
    // 窗口操作事件回调
    var onWindowDocked: ((DockedWindow) -> Void)?
    var onWindowUndocked: ((UUID, UndockReason) -> Void)?
    var onAllWindowsUndocked: (() -> Void)?
    
    private init() {}
    
    func dockWindow(_ axWindow: AxWindow, to edge: DockEdge) {
        guard prefsManager.isEnabled else {
            DockitLogger.shared.logInfo("Dockit 已禁用")
            return
        }
        
        guard let app = NSWorkspace.shared.frontmostApplication,
              let window = Windows.shared.inner.first(where: { $0.axWindow == axWindow }) else {
            DockitLogger.shared.logError("无法获取应用或窗口信息")
            NotificationHelper.show(
                type: .warning,
                title: "无法获取前台窗口"
            )
            return
        }
        
        let dockedWindow = DockedWindow(axWindow: axWindow, edge: edge)
        
        DockitLogger.shared.logWindowDocked(
            try? axWindow.title(),
            edge: edge,
            frame: try? axWindow.frame()
        )
        
        NotificationHelper.show(
            type: .custom(edge == .left ? "arrowshape.left.fill" : "arrowshape.right.fill"),
            title: try! axWindow.title() ?? "",
            description: "已停靠到\(edge == .left ? "左" : "右")边",
            windowIcon: NotificationHelper.getAppIconForWindow(axWindow)
        )
        
        axWindow.dockTo(edge, exposedPixels: prefsManager.exposedPixels)
        
        // 通知 DockitManager 窗口已停靠
        onWindowDocked?(dockedWindow)
    }
    
    func undockWindow(_ dockedWindow: DockedWindow, reason: UndockReason = .userAction) {
        // 统一使用存储的标题记录日志
        // 如果窗口已关闭，frame 可能无法获取，所以传 nil
        DockitLogger.shared.logWindowUndocked(
            dockedWindow.storedTitle,
            reason: reason,
            frame: reason == .windowClosed ? nil : try? dockedWindow.axWindow.frame()
        )

        if let observer = dockedWindow.observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        
        // 使用存储的标题来显示通知
        let windowTitle = dockedWindow.storedTitle
        
        NotificationHelper.show(
            type: .success,
            title: windowTitle,
            description: "已取消停靠",
            // 获取图标仍然尝试使用 axWindow，如果失败则不显示图标
            windowIcon: NotificationHelper.getAppIconForWindow(dockedWindow.axWindow)
        )
        
        // 通知 DockitManager 窗口已取消停靠
        onWindowUndocked?(dockedWindow.id, reason)
    }
    
    func undockAllWindows(windows: [DockedWindow], type: UndockAllWindowsType = .normal) {
        DockitLogger.shared.logInfo("开始取消停靠所有窗口 (\(windows.count)个)")
        
        windows.forEach { window in
            // 将窗口恢复到原始位置 (仅在非退出时执行动画恢复)
            let originalFrame = window.originalFrame
            let targetFrame = type == .normal ? originalFrame : (try? window.axWindow.frame()) ?? originalFrame // 退出时直接使用当前位置
            
            // 尝试将窗口恢复到原始位置，忽略错误
            DockitLogger.shared.logInfo("恢复窗口「\(window.storedTitle)」到 [\(Int(targetFrame.origin.x)),\(Int(targetFrame.origin.y))]")
            
            // 退出时不激活窗口
            if type == .normal {
                if let windowToFocus = Windows.shared.inner.first(where: { $0.axWindow == window.axWindow }) {
                    windowToFocus.focus()
                    DockitLogger.shared.logInfo("已激活窗口 \(window.storedTitle)")
                }
            }
            
            try? window.axWindow.setPosition(targetFrame.origin)
        }
        
        NotificationHelper.show(
            type: .success,
            title: "已取消停靠所有窗口"
        )
        
        // 通知 DockitManager 所有窗口已取消停靠，DockitManager 会在这里清理 dockedWindows 列表
        onAllWindowsUndocked?()
    }
    
    func dockActiveWindow(to edge: DockEdge) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            DockitLogger.shared.logError("无法获取当前活动应用")
            return
        }
        
        let axApp = AxApplication(element: AXUIElementCreateApplication(app.processIdentifier))
        guard let window = try? axApp.focusedWindow() else {
            DockitLogger.shared.logError("无法获取当前焦点窗口")
            return
        }
        
        dockWindow(window, to: edge)
    }
} 
