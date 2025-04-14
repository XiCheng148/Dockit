import AppKit
import Foundation
import SwiftUI
import Defaults

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
    
    // 服务依赖
    private let prefsManager = PreferencesManager.shared
    private let windowService = WindowDockingService.shared
    private let spaceService = SpaceMonitorService.shared
    private let eventMonitor = DockitEventMonitor()
    
    // 对外暴露设置属性的访问器
    var exposedPixels: Double {
        get { prefsManager.exposedPixels }
        set { prefsManager.updateExposedPixels(newValue) }
    }
    
    var triggerAreaWidth: Double {
        get { prefsManager.triggerAreaWidth }
        set { prefsManager.updateTriggerAreaWidth(newValue) }
    }
    
    var isEnabled: Bool {
        get { prefsManager.isEnabled }
        set { prefsManager.updateIsEnabled(newValue) }
    }
    
    var respectSpaces: Bool {
        get { prefsManager.respectSpaces }
        set { prefsManager.updateRespectSpaces(newValue) }
    }
    
    var fps: Int {
        get { prefsManager.fps }
        set { prefsManager.updateFps(newValue) }
    }
    
    var notchStyle: String {
        get { prefsManager.notchStyle }
        set { prefsManager.updateNotchStyle(newValue) }
    }
    
    var showPreview: Bool {
        get { prefsManager.showPreview }
        set { prefsManager.updateShowPreview(newValue) }
    }
    
    private init() {
        // 设置回调
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        // 设置偏好回调
        prefsManager.onExposedPixelsChanged = { [weak self] newValue in
            self?.dockedWindows.forEach { window in
                window.axWindow.dockTo(window.edge, exposedPixels: newValue)
            }
        }
        
        prefsManager.onIsEnabledChanged = { [weak self] isEnabled in
            if !isEnabled {
                self?.undockAllWindows()
            }
        }
        
        prefsManager.onFpsChanged = { [weak self] fps in
            self?.eventMonitor.updateFPS(fps)
        }
        
        // 设置窗口服务回调
        windowService.onWindowDocked = { [weak self] dockedWindow in
            guard let self = self else { return }
            
            // 检查窗口是否已经停靠
            if let existingWindowIndex = self.dockedWindows.firstIndex(where: { $0.axWindow == dockedWindow.axWindow }) {
                // 如果已停靠且边缘相同，则忽略
                if self.dockedWindows[existingWindowIndex].edge == dockedWindow.edge {
                    DockitLogger.shared.logInfo("窗口已经停靠在\(dockedWindow.edge == .left ? "左" : "右")边")
                    return
                }
                // 如果已停靠但边缘不同，则先取消停靠
                self.dockedWindows.remove(at: existingWindowIndex)
            }
            
            self.dockedWindows.append(dockedWindow)
        }
        
        windowService.onWindowUndocked = { [weak self] id, reason in
            self?.dockedWindows.removeAll { $0.id == id }
        }
        
        windowService.onAllWindowsUndocked = { [weak self] in
            self?.dockedWindows.removeAll()
        }
        
        // 设置空间切换回调
        spaceService.onSpaceChanged = { [weak self] in
            self?.handleSpaceChange()
        }
    }
    
    private func setupEventMonitor() {
        eventMonitor.onMouseMoved = { [weak self] point in
            self?.handleMouseMovement(point)
        }
    }
    
    // MARK: - 公共方法
    
    func dockWindow(_ axWindow: AxWindow, to edge: DockEdge) {
        windowService.dockWindow(axWindow, to: edge)
    }
    
    func undockWindow(_ id: UUID, reason: UndockReason = .userAction) {
        if let window = dockedWindows.first(where: { $0.id == id }) {
            windowService.undockWindow(window, reason: reason)
        }
    }
    
    func undockAllWindows(type: UndockAllWindowsType = .normal) {
        let windowsToUndock = dockedWindows // 获取当前停靠窗口的副本
        if windowsToUndock.isEmpty {
            DockitLogger.shared.logInfo("没有需要取消停靠的窗口")
            return
        }
        DockitLogger.shared.logInfo("准备取消停靠所有窗口")
        // 在调用 undockAllWindows 时添加 windows: 标签
        windowService.undockAllWindows(windows: windowsToUndock, type: type)
    }
    
    func dockActiveWindow(to edge: DockEdge) {
        windowService.dockActiveWindow(to: edge)
    }
    
    // MARK: - 私有方法
    
    private func handleMouseMovement(_ point: NSPoint) {
        let currentModifiers = NSEvent.modifierFlags
        let expandModifiers = NSEvent.ModifierFlags(rawValue: prefsManager.expandModifiers)
        let collapseModifiers = NSEvent.ModifierFlags(rawValue: prefsManager.collapseModifiers)
        
        dockedWindows.forEach { dockedWindow in
            // 如果无法获取窗口框架，说明窗口可能已经关闭
            guard let _ = try? dockedWindow.axWindow.frame() else {
                undockWindow(dockedWindow.id, reason: .windowClosed)
                return
            }
            
            let isWindowVisible = spaceService.isWindowVisibleOnScreen(dockedWindow.axWindow)
            
            if respectSpaces && !isWindowVisible {
                return
            }
            
            let allOtherWindowsHidden = dockedWindows
                .filter { $0.id != dockedWindow.id }
                .allSatisfy { !$0.isVisible }
            
            // 重构展开/收起逻辑
            var shouldShow = dockedWindow.isVisible
            
            if dockedWindow.isVisible {
                // 窗口已展开，检查是否需要收起
                if !dockedWindow.windowArea.contains(point) {
                    if collapseModifiers.isEmpty {
                        // 没有设置收起触发键，直接收起
                        shouldShow = false
                    } else if currentModifiers == collapseModifiers {
                        // 设置了收起触发键，且按下了正确的触发键，才收起
                        shouldShow = false
                    }
                }
            } else {
                // 窗口已收起，检查是否需要展开
                if dockedWindow.triggerArea.contains(point) && allOtherWindowsHidden {
                    if expandModifiers.isEmpty {
                        // 没有设置展开触发键，直接展开
                        shouldShow = true
                    } else if currentModifiers == expandModifiers {
                        // 设置了展开触发键，且按下了正确的触发键，才展开
                        shouldShow = true
                    }
                }
            }
            
            // 状态发生变化时才执行展开/收起操作
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
    
    private func handleSpaceChange() {
        // 遍历所有已停靠的窗口
        dockedWindows.forEach { dockedWindow in
            // 如果窗口当前是展开状态
            if dockedWindow.isVisible {
                // 检查窗口是否在当前空间可见
                let isVisible = spaceService.isWindowVisibleOnScreen(dockedWindow.axWindow)
                if !isVisible {
                    // 如果窗口不在当前空间，则收起窗口
                    if let index = dockedWindows.firstIndex(where: { $0.id == dockedWindow.id }) {
                        var updatedWindow = dockedWindow
                        updatedWindow.isVisible = false
                        dockedWindows[index] = updatedWindow
                        
                        // 使用存储的标题记录日志
                        DockitLogger.shared.logInfo("空间切换 - 收起窗口「\(dockedWindow.storedTitle)」")
                        dockedWindow.axWindow.dockTo(dockedWindow.edge, exposedPixels: exposedPixels)
                    }
                }
            }
        }
    }
} 
