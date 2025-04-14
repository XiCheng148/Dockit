import AppKit
import Foundation
import SwiftUI


struct DockedWindow: Identifiable {
    let id: UUID
    let axWindow: AxWindow
    let edge: DockEdge
    let originalFrame: CGRect
    let storedTitle: String
    var observer: AXObserver?
    
    var isVisible: Bool = false
    
    init(axWindow: AxWindow, edge: DockEdge) {
        self.id = UUID()
        self.axWindow = axWindow
        self.edge = edge
        self.originalFrame = (try? axWindow.frame()) ?? .zero
        self.storedTitle = (try? axWindow.title()) ?? "未知标题"
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
            
            guard let dockedWindow = manager.dockedWindows.first(where: { $0.axWindow == axWindow }) else {
                return
            }
            
            switch notification as String {
            case kAXUIElementDestroyedNotification:
                DockitLogger.shared.logInfo("监测到窗口关闭事件，准备取消停靠: \(dockedWindow.storedTitle)")
                manager.undockWindow(dockedWindow.id, reason: .windowClosed)
                
            case kAXWindowMovedNotification:
                if let dockedWindow = manager.dockedWindows.first(where: { $0.axWindow == axWindow }),
                   dockedWindow.isVisible,
                   let currentFrame = try? axWindow.frame() {
                    let targetScreen = NSScreen.main!
                    
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
                    
                    let dockedPosition = WindowPositionCalculator.calculateCollapsedPosition(
                        window: currentFrame,
                        edge: dockedWindow.edge,
                        screen: targetScreen,
                        exposedPixels: DockitManager.shared.exposedPixels
                    )
                    let distance = abs(currentFrame.origin.x - dockedPosition.x)
                    
                    if !isNormalDockMovement && distance > 50 {
                        DockitLogger.shared.logWindowMoved(
                            dockedWindow.storedTitle,
                            distance: distance,
                            frame: try? axWindow.frame()
                        )
                        manager.undockWindow(dockedWindow.id, reason: .dragDistance)
                    }
                }
                
            case kAXWindowResizedNotification:
                // 仅在窗口可见（展开）时处理大小改变
                if let currentFrame = try? axWindow.frame(), dockedWindow.isVisible {
                    let targetScreen = NSScreen.main!
                    
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
                    
                    let dockedPosition = WindowPositionCalculator.calculateCollapsedPosition(
                        window: currentFrame,
                        edge: dockedWindow.edge,
                        screen: targetScreen,
                        exposedPixels: DockitManager.shared.exposedPixels
                    )
                    let distance = abs(currentFrame.origin.x - dockedPosition.x)
                    
                    if !isNormalDockMovement && distance > 50 {
                        DockitLogger.shared.logWindowMoved(
                            dockedWindow.storedTitle,
                            distance: distance,
                            frame: try? axWindow.frame()
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
        
        let windowInFlippedCoords = currentFrame.convert(from: .accessibility, to: .flipped, in: screen)
        
        return CGRect(
            x: currentFrame.origin.x,
            y: windowInFlippedCoords.origin.y,
            width: currentFrame.width,
            height: currentFrame.height
        )
    }
}
