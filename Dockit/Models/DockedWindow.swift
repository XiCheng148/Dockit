import AppKit
import Foundation
import SwiftUI


struct DockedWindow: Identifiable {
    let id: UUID
    let axWindow: AxWindow
    let edge: DockEdge
    let originalFrame: CGRect
    var observer: AXObserver?
    
    var isVisible: Bool = false
    
    init(axWindow: AxWindow, edge: DockEdge) {
        self.id = UUID()
        self.axWindow = axWindow
        self.edge = edge
        self.originalFrame = (try? axWindow.frame()) ?? .zero
        addObserver()
    }
    
    private mutating func addObserver() {
        let notifications = [
            kAXUIElementDestroyedNotification,  // 窗口关闭
            kAXWindowMovedNotification,         // 窗口移动
            kAXWindowResizedNotification        // 窗口大小改变
        ]
        
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            let manager = DockitManager.shared
            let axWindow = AxWindow(element: element)
            
            switch notification as String {
            case kAXUIElementDestroyedNotification:
                // 窗口关闭时取消停靠
                if let id = manager.dockedWindows.first(where: { $0.axWindow == axWindow })?.id {
                    // 窗口已关闭，使用安全的方式获取标题
                    let windowTitle = (try? axWindow.title()) ?? "未知窗口"
                   NotificationHelper.show(
                       type: .success,
                       title: windowTitle,
                       description: "已取消停靠",
                       windowIcon: NotificationHelper.getAppIconForWindow(axWindow)
                   )
                    manager.undockWindow(id, reason: .windowClosed)
                }
                
            case kAXWindowMovedNotification:
                if let dockedWindow = manager.dockedWindows.first(where: { $0.axWindow == axWindow }),
                   dockedWindow.isVisible,
                   let currentFrame = try? axWindow.frame() {
                    let targetScreen = NSScreen.main!
                    
                    // 使用新工具类判断是否为正常停靠移动
                    let isNormalDockMovement = WindowPositionCalculator.isCollapsedPosition(
                        window: currentFrame,
                        edge: dockedWindow.edge,
                        screen: targetScreen,
                        exposedPixels: DockitManager.shared.exposedPixels
                    ) || WindowPositionCalculator.isExpandedPosition(
                        window: currentFrame,
                        edge: dockedWindow.edge,
                        screen: targetScreen
                    )
                    
                    // 计算与停靠位置的距离
                    let dockedPosition = WindowPositionCalculator.calculateCollapsedPosition(
                        window: currentFrame,
                        edge: dockedWindow.edge,
                        screen: targetScreen,
                        exposedPixels: DockitManager.shared.exposedPixels
                    )
                    let distance = abs(currentFrame.origin.x - dockedPosition.x)
                    
                    // 只有不是正常的停靠移动，且超过阈值时才取消停靠
                    if !isNormalDockMovement && distance > 50 {
                        DockitLogger.shared.logWindowMoved(
                            try? axWindow.title(),
                            distance: distance,
                            frame: try? axWindow.frame()
                        )
                       NotificationHelper.show(
                           type: .success,
                           title: (try? axWindow.title()) ?? "未知窗口",
                           description: "已取消停靠",
                           windowIcon: NotificationHelper.getAppIconForWindow(axWindow)
                       )
                        manager.undockWindow(dockedWindow.id, reason: .dragDistance)
                    }
                }
                
            default:
                break
            }
        }
        
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        var observer: AXObserver?
        AXObserverCreate(app.processIdentifier, callback, &observer)
        
        guard let observer = observer else { return }
        for notification in notifications {
            try? axWindow.subscribeToNotification(observer, notification, nil)
        }
        
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        
        self.observer = observer
    }
    
    var triggerArea: CGRect {
        guard let currentFrame = try? axWindow.frame(),
              let screen = NSScreen.containing(currentFrame) ?? NSScreen.main else { return .zero }
        
        let width = DockitManager.shared.triggerAreaWidth
        
        // 使用统一的坐标转换方法
        let windowInFlippedCoords = currentFrame.convert(from: .accessibility, to: .flipped, in: screen)
        
        switch edge {
        case .left:
            return CGRect(
                x: screen.frame.minX,
                y: windowInFlippedCoords.origin.y,
                width: width,
                height: currentFrame.height
            )
        case .right:
            return CGRect(
                x: screen.frame.maxX - width,
                y: windowInFlippedCoords.origin.y,
                width: width,
                height: currentFrame.height
            )
        }
    }
    
    var windowArea: CGRect {
        guard let currentFrame = try? axWindow.frame(),
              let screen = NSScreen.containing(currentFrame) ?? NSScreen.main else { return .zero }
        
        // 使用统一的坐标转换方法
        let windowInFlippedCoords = currentFrame.convert(from: .accessibility, to: .flipped, in: screen)
        
        return CGRect(
            x: currentFrame.origin.x,
            y: windowInFlippedCoords.origin.y,
            width: currentFrame.width,
            height: currentFrame.height
        )
    }
}
