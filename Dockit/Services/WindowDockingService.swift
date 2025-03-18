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
        // 如果是窗口关闭，就不要尝试获取窗口信息了
        if reason != .windowClosed {
            DockitLogger.shared.logWindowUndocked(
                try? dockedWindow.axWindow.title(),
                reason: reason,
                frame: try? dockedWindow.axWindow.frame()
            )
        } else {
            DockitLogger.shared.logWindowUndocked(
                "未知窗口",  // 窗口关闭时使用默认标题
                reason: reason,
                frame: nil
            )
        }

        if let observer = dockedWindow.observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        
        // 安全地获取窗口标题
        let windowTitle = (try? dockedWindow.axWindow.title()) ?? "未知窗口"
        
        NotificationHelper.show(
            type: .success,
            title: windowTitle,
            description: "已取消停靠",
            windowIcon: NotificationHelper.getAppIconForWindow(dockedWindow.axWindow)
        )
        
        // 通知 DockitManager 窗口已取消停靠
        onWindowUndocked?(dockedWindow.id, reason)
    }
    
    func undockAllWindows(_ dockedWindows: [DockedWindow], type: UndockAllWindowsType = .normal) {
        DockitLogger.shared.logUndockAllShortcut()
        
        // 先检查是不是空的
        if dockedWindows.isEmpty {
            DockitLogger.shared.logInfo("没有停靠的窗口")
            if type == .normal {
               NotificationHelper.show(
                   type: .warning,
                   title: "没有停靠的窗口"
               )
            }
            return
        }
        
        dockedWindows.forEach { window in
            DockitLogger.shared.logWindowUndocked(
                try? window.axWindow.title(),
                reason: .userAction,
                frame: window.originalFrame
            )
            
            // 获取所有屏幕
            let screens = NSScreen.screens
            var targetFrame = window.originalFrame
            
            // 检查原始位置是否大部分在所有屏幕外
            let isLargelyOffscreen = window.originalFrame.isLargelyOffscreen(threshold: 0.3)
            
            if isLargelyOffscreen {
                // 如果窗口大部分在屏幕外，将其移动到当前屏幕或主屏幕中央
                if let currentScreen = NSScreen.mostIntersecting(with: window.originalFrame) ?? NSScreen.main {
                    let screenCenter = CGPoint(
                        x: currentScreen.frame.midX - (window.originalFrame.width / 2),
                        y: currentScreen.frame.midY - (window.originalFrame.height / 2)
                    )
                    targetFrame.origin = screenCenter
                    
                    DockitLogger.shared.logInfo("窗口 \(try? window.axWindow.title() ?? "") 原位置在屏幕外，已移至\(currentScreen == NSScreen.main ? "主" : "当前")屏幕中央")
                }
            }
            
            // 在设置位置前先focus窗口
            if let windowToFocus = Windows.shared.inner.first(where: { $0.axWindow == window.axWindow }) {
                windowToFocus.focus()
                DockitLogger.shared.logInfo("已激活窗口 \(try? window.axWindow.title() ?? "")")
            }
            
            try? window.axWindow.setPosition(targetFrame.origin)
        }
        
        NotificationHelper.show(
            type: .success,
            title: "已取消停靠所有窗口"
        )
        
        // 通知 DockitManager 所有窗口已取消停靠
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
