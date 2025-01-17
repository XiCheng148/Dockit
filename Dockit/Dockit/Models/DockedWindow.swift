import AppKit
import Foundation
import SwiftUI
import NotchNotification

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
                    NotchNotification.present(
                        leadingView: Rectangle().hidden().frame(width: 4),
                        bodyView: HStack() {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).padding(.trailing, 16)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(((try? axWindow.title()) ?? "") + " 已取消停靠").lineLimit(1).font(.system(size: 14)).bold()
                            }
                        },
                        interval: 2
                    )
                    manager.undockWindow(id, reason: .windowClosed)
                }
                
            case kAXWindowMovedNotification:
                if let dockedWindow = manager.dockedWindows.first(where: { $0.axWindow == axWindow }),
                   dockedWindow.isVisible,
                   let currentFrame = try? axWindow.frame(),
                   let screen = NSScreen.screens.first(where: { $0.frame.intersects(currentFrame) }) {
                    // 计算停靠位置的 X 坐标
                    let dockedX: CGFloat
                    switch dockedWindow.edge {
                    case .left:
                        dockedX = screen.frame.minX
                    case .right:
                        dockedX = screen.frame.maxX - currentFrame.width
                    }
                    
                    // 计算与停靠位置的距离
                    let distance = abs(currentFrame.origin.x - dockedX)
                    
                    // 检查是否是正常的展开/收起移动
                    let isNormalDockMovement: Bool
                    switch dockedWindow.edge {
                    case .left:
                        isNormalDockMovement = currentFrame.origin.x == screen.frame.minX || // 展开状态
                                              currentFrame.origin.x == screen.frame.minX - currentFrame.width + manager.exposedPixels // 收起状态
                    case .right:
                        isNormalDockMovement = currentFrame.origin.x == screen.frame.maxX - currentFrame.width || 
                                              currentFrame.origin.x == screen.frame.maxX - manager.exposedPixels
                    }
                    
                    // 只有不是正常的停靠移动，且超过阈值时才取消停靠
                    if !isNormalDockMovement && distance > 50 {
                        DockitLogger.shared.logWindowMoved(
                            try? axWindow.title(),
                            distance: distance,
                            frame: try? axWindow.frame()
                        )
                        NotchNotification.present(
                            leadingView: Rectangle().hidden().frame(width: 4),
                            bodyView: HStack() {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).padding(.trailing, 16)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(((try? axWindow.title()) ?? "")).lineLimit(1).font(.system(size: 14)).bold()
                                    Text("已取消停靠").font(.system(size: 12))
                                }
                            },
                            interval: 2
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
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(currentFrame) }) else { return .zero }
        
        let width = DockitManager.shared.triggerAreaWidth
        
        // 将窗口坐标转换为相对于当前屏幕的 Cocoa 坐标系
        let y = screen.frame.maxY - currentFrame.maxY
        
        switch edge {
        case .left:
            return CGRect(
                x: screen.frame.minX,
                y: y,
                width: width,
                height: currentFrame.height
            )
        case .right:
            return CGRect(
                x: screen.frame.maxX - width,
                y: y,
                width: width,
                height: currentFrame.height
            )
        }
    }
    
    var windowArea: CGRect {
        guard let currentFrame = try? axWindow.frame(),
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(currentFrame) }) else { return .zero }
        
        // 将窗口坐标转换为相对于当前屏幕的 Cocoa 坐标系
        let y = screen.frame.maxY - currentFrame.maxY
        
        return CGRect(
            x: currentFrame.origin.x,
            y: y,
            width: currentFrame.width,
            height: currentFrame.height
        )
    }
} 
