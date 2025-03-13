import AppKit
import Foundation
import SwiftUI
import Defaults
// import DynamicNotchKit
import NotchNotification

class DockitManager: ObservableObject {
    static let shared = DockitManager()
    
    @Published private(set) var dockedWindows: [DockedWindow] = [] {
        didSet {
            if dockedWindows.isEmpty {
                eventMonitor.stopMonitoring()
                DockitLogger.shared.logInfo("所有窗口已取消停靠，停止鼠标监听")
            } else if oldValue.isEmpty {
                setupEventMonitor()
                eventMonitor.startMonitoring()
            }
        }
    }
    
    @Published private var _exposedPixels: Double
    var exposedPixels: Double {
        get { _exposedPixels }
        set {
            _exposedPixels = newValue
            Defaults[.exposedPixels] = Int(newValue)
            // 当设置改变时更新所有已停靠窗口
            dockedWindows.forEach { window in
                window.axWindow.dockTo(window.edge, exposedPixels: newValue)
            }
        }
    }
    
    @Published private var _triggerAreaWidth: Double
    var triggerAreaWidth: Double {
        get { _triggerAreaWidth }
        set {
            _triggerAreaWidth = newValue
            Defaults[.triggerAreaWidth] = Int(newValue)
        }
    }
    
    @Published private var _isEnabled: Bool
    var isEnabled: Bool {
        get { _isEnabled }
        set {
            _isEnabled = newValue
            Defaults[.isEnabled] = newValue
            if !newValue {
                undockAllWindows()
            }
        }
    }
    
    @Published private var _respectSpaces: Bool
    var respectSpaces: Bool {
        get { _respectSpaces }
        set {
            _respectSpaces = newValue
            Defaults[.respectSpaces] = newValue
        }
    }
    
    @Published private var _fps: Double
    var fps: Double {
        get { _fps }
        set {
            _fps = newValue
            Defaults[.fps] = Int(newValue)
            eventMonitor.updateFPS(newValue)
        }
    }
    
    private let eventMonitor = DockitEventMonitor()
    
    private var workspaceNotificationObserver: NSObjectProtocol?
    
    private init() {
        self._exposedPixels = Double(Defaults[.exposedPixels])
        self._triggerAreaWidth = Double(Defaults[.triggerAreaWidth])
        self._isEnabled = Defaults[.isEnabled]
        self._respectSpaces = Defaults[.respectSpaces]
        self._fps = Double(Defaults[.fps])
        
        DockitLogger.shared.logInfo("DockitManager 初始化 - 露出像素: \(exposedPixels)px, 触发区域宽度: \(triggerAreaWidth)px")
        
        // 添加工作区切换监听
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSpaceChange()
        }
    }
    
    func dockWindow(_ axWindow: AxWindow, to edge: DockEdge) {
        guard isEnabled else {
            DockitLogger.shared.logInfo("Dockit 已禁用")
            return
        }
        
        // 检查窗口是否已经停靠
        if let existingWindow = dockedWindows.first(where: { $0.axWindow == axWindow }) {
            // 如果已停靠且边缘相同，则忽略
            if existingWindow.edge == edge {
                DockitLogger.shared.logInfo("窗口已经停靠在\(edge == .left ? "左" : "右")边")
                return
            }
            // 如果已停靠但边缘不同，则先取消停靠
            undockWindow(existingWindow.id)
        }
        
        setupEventMonitor()
        
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
        dockedWindows.append(dockedWindow)
        
        DockitLogger.shared.logWindowDocked(
            try? axWindow.title(),
            edge: edge,
            frame: try? axWindow.frame()
        )
        // let img = edge == .left ? Image(systemName: "arrowshape.left.fill") : Image(systemName: "arrowshape.right.fill")
        let img = edge == .left ? Image(systemName: "arrowshape.left.fill") : Image(systemName: "arrowshape.right.fill")
        
        NotificationHelper.show(
            type: .custom(edge == .left ? "arrowshape.left.fill" : "arrowshape.right.fill"),
            title: try! axWindow.title() ?? "",
            description: "已停靠到\(edge == .left ? "左" : "右")边"
        )

        // let dynamicNotch = DynamicNotchInfo (
        //     icon: edge == .left ? 
        //         Image(systemName: "arrowshape.left.fill") : 
        //         Image(systemName: "arrowshape.right.fill"),
        //     title: "\(try? axWindow.title())",
        //     description: "已停靠到\(edge == .left ? "左" : "右")边"
        // )
        // dynamicNotch.show(for: 2)

        axWindow.dockTo(edge, exposedPixels: exposedPixels)
    }
    
    func undockWindow(_ id: UUID, reason: UndockReason = .userAction) {
        guard let window = dockedWindows.first(where: { $0.id == id }) else { return }
        
        // 如果是窗口关闭，就不要尝试获取窗口信息了
        if reason != .windowClosed {
            DockitLogger.shared.logWindowUndocked(
                try? window.axWindow.title(),
                reason: reason,
                frame: try? window.axWindow.frame()
            )
        } else {
            DockitLogger.shared.logWindowUndocked(
                "未知窗口",  // 窗口关闭时使用默认标题
                reason: reason,
                frame: nil
            )
        }

        if let observer = window.observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        
        // 先移除窗口，再发送通知
        dockedWindows.removeAll { $0.id == id }
        
        // 安全地获取窗口标题
        let windowTitle = (try? window.axWindow.title()) ?? "未知窗口"
        
        NotificationHelper.show(
            type: .success,
            title: windowTitle,
            description: "已取消停靠"
        )
    }
    
    func undockAllWindows(type: UndockAllWindowsType = .normal) {
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
            let isLargelyOffscreen = screens.allSatisfy { screen in
                let intersection = screen.frame.intersection(window.originalFrame)
                let visibleArea = intersection.width * intersection.height
                let totalArea = window.originalFrame.width * window.originalFrame.height
                return visibleArea / totalArea < 0.3 // 如果可见面积小于30%，认为是大部分在屏幕外
            }
            
            if isLargelyOffscreen {
                // 如果窗口大部分在屏幕外，将其移动到当前屏幕或主屏幕中央
                if let currentScreen = NSScreen.screens.first(where: { $0.frame.intersects(window.originalFrame) }) ?? NSScreen.main {
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
        
        dockedWindows.removeAll()
        
        NotificationHelper.show(
            type: .success,
            title: "已取消停靠所有窗口"
        )
    }
    
    private func setupEventMonitor() {
        eventMonitor.onMouseMoved = { [weak self] point in
            self?.handleMouseMovement(point)
        }
    }
    
    func handleMouseMovement(_ point: NSPoint) {
        dockedWindows.forEach { dockedWindow in
            // 如果无法获取窗口框架，说明窗口可能已经关闭
            guard let _ = try? dockedWindow.axWindow.frame() else {
                undockWindow(dockedWindow.id, reason: .windowClosed)
                return
            }
            
            let isWindowVisible = isWindowVisibleOnScreen(dockedWindow.axWindow)
            
            if respectSpaces && !isWindowVisible {
                return
            }
            
            // 检查是否所有其他窗口都是隐藏状态
            let allOtherWindowsHidden = dockedWindows
                .filter { $0.id != dockedWindow.id }  // 排除当前窗口
                .allSatisfy { !$0.isVisible }         // 检查是否都是隐藏状态
            
            let shouldShow = dockedWindow.isVisible 
                ? dockedWindow.windowArea.contains(point)
                : (dockedWindow.triggerArea.contains(point) && allOtherWindowsHidden)
                
            if shouldShow != dockedWindow.isVisible {
                var updatedWindow = dockedWindow
                updatedWindow.isVisible = shouldShow
                
                if shouldShow {
                    DockitLogger.shared.logWindowShown(
                        try? dockedWindow.axWindow.title(),
                        frame: try? dockedWindow.axWindow.frame()
                    )
                } else {
                    DockitLogger.shared.logWindowHidden(
                        try? dockedWindow.axWindow.title(),
                        frame: try? dockedWindow.axWindow.frame()
                    )
                }
                
                if let index = dockedWindows.firstIndex(where: { $0.id == dockedWindow.id }) {
                    dockedWindows[index] = updatedWindow
                }
                
                if shouldShow {
                    if let window = Windows.shared.inner.first(where: { $0.axWindow == dockedWindow.axWindow }) {
                        window.focus()
                    }
                    
                    dockedWindow.axWindow.expandTo(dockedWindow.edge)
                } else {
                    dockedWindow.axWindow.dockTo(dockedWindow.edge, exposedPixels: exposedPixels)
                }
            }
        }
    }
    
    private func isWindowVisibleOnScreen(_ window: AxWindow) -> Bool {
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
    
    private func handleSpaceChange() {
        // 遍历所有已停靠的窗口
        dockedWindows.forEach { dockedWindow in
            // 如果窗口当前是展开状态
            if dockedWindow.isVisible {
                // 检查窗口是否在当前空间可见
                let isVisible = isWindowVisibleOnScreen(dockedWindow.axWindow)
                if !isVisible {
                    // 如果窗口不在当前空间，则收起窗口
                    if let index = dockedWindows.firstIndex(where: { $0.id == dockedWindow.id }) {
                        var updatedWindow = dockedWindow
                        updatedWindow.isVisible = false
                        dockedWindows[index] = updatedWindow
                        
                        DockitLogger.shared.logInfo("空间切换 - 收起窗口「\(try? dockedWindow.axWindow.title() ?? "")」")
                        dockedWindow.axWindow.dockTo(dockedWindow.edge, exposedPixels: exposedPixels)
                    }
                }
            }
        }
    }
    
    deinit {
        if let observer = workspaceNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
} 
