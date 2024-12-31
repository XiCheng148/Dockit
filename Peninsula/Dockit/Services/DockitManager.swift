import AppKit
import Foundation
import SwiftUI

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
    @Published var exposedPixels: Double = 10 {
        didSet {
            // 当设置改变时更新所有已停靠窗口
            dockedWindows.forEach { window in
                window.axWindow.dockTo(window.edge, exposedPixels: exposedPixels)
            }
        }
    }
    @Published var triggerAreaWidth: Double = 10
    @Published var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                undockAllWindows()
            }
        }
    }
    @Published var respectSpaces: Bool = true
    @Published var fps: Double = 30 {
        didSet {
            // 更新事件监听器的 FPS
            eventMonitor.updateFPS(fps)
        }
    }
    
    private let eventMonitor = DockitEventMonitor()
    
    private init() {
        DockitLogger.shared.logInfo("DockitManager 初始化 - 露出像素: \(exposedPixels)px, 触发区域宽度: \(triggerAreaWidth)px")
    }
    
    func dockWindow(_ axWindow: AxWindow, to edge: DockEdge) {
        guard isEnabled else {
            DockitLogger.shared.logInfo("Dockit 已禁用")
            return
        }
        
        setupEventMonitor()
        
        guard let app = NSWorkspace.shared.frontmostApplication,
              let window = Windows.shared.inner.first(where: { $0.axWindow == axWindow }) else {
            DockitLogger.shared.logError("无法获取应用或窗口信息")
            return
        }
        
        let dockedWindow = DockedWindow(axWindow: axWindow, edge: edge)
        dockedWindows.append(dockedWindow)
        
        DockitLogger.shared.logWindowDocked(
            try? axWindow.title(),
            edge: edge,
            frame: try? axWindow.frame()
        )
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
                "未知窗口",  // 或者可以缓存窗口标题
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
        
        // 先移除窗口，再停止监听
        dockedWindows.removeAll { $0.id == id }
    }
    
    func undockAllWindows() {
        DockitLogger.shared.logUndockAllShortcut()
        // 先检查是不是空的
        if dockedWindows.isEmpty {
            DockitLogger.shared.logInfo("没有停靠的窗口")
            return
        }
        dockedWindows.forEach { window in
            DockitLogger.shared.logWindowUndocked(
                try? window.axWindow.title(),
                reason: .userAction,
                frame: window.originalFrame
            )
            try? window.axWindow.setPosition(window.originalFrame.origin)
            // try? window.axWindow.setSize(window.originalFrame.size)
        }
        dockedWindows.removeAll()
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
                : (dockedWindow.triggerArea.contains(point) && allOtherWindowsHidden) // 增加条件：所有其他窗口都隐藏
                
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
                    
                    if let currentFrame = try? dockedWindow.axWindow.frame(),
                       let screen = NSScreen.main {
                        var newOrigin = currentFrame.origin
                        switch dockedWindow.edge {
                        case .left:
                            newOrigin.x = 0
                        case .right:
                            newOrigin.x = screen.frame.width - currentFrame.width
                        }
                        try? dockedWindow.axWindow.setPosition(newOrigin)
                    }
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
} 
