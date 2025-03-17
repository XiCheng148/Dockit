import AppKit
import Foundation
import SwiftUI

extension DockEdge {
    var notificationType: NotificationType {
        switch self {
        case .left:
            return .dockLeft
        case .right:
            return .dockRight
        }
    }
}

extension AxWindow {
    func setPosition(_ position: CGPoint) throws {
        var point = position
        let axValue = AXValueCreate(.cgPoint, &point)!
        let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axValue)
        if result != .success {
            DockitLogger.shared.logError("设置窗口位置失败")
            throw AxError.runtimeError
        }
    }
    
    func setSize(_ size: CGSize) throws {
        var cgSize = size
        let axValue = AXValueCreate(.cgSize, &cgSize)!
        let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axValue)
        if result != .success {
            DockitLogger.shared.logError("设置窗口大小失败")
            throw AxError.runtimeError
        }
    }

    func dockTo(_ edge: DockEdge, exposedPixels: CGFloat) {
        guard let currentFrame = try? frame() else {
            DockitLogger.shared.logError("无法获取窗口信息")
            return
        }
        
        // 只使用主屏幕
        guard let mainScreen = NSScreen.main else {
            DockitLogger.shared.logError("无法获取主屏幕")
            return
        }
        
        // 检查窗口是否在主屏幕上
        if !mainScreen.frame.intersects(currentFrame) {
            DockitLogger.shared.logInfo("窗口不在主屏幕上，将被移动至主屏幕")
            
            // 将窗口移动到主屏幕中心
            let centerX = mainScreen.frame.midX - (currentFrame.width / 2)
            let centerY = mainScreen.frame.midY - (currentFrame.height / 2)
            
            try? setPosition(CGPoint(x: centerX, y: centerY))
        }
        
        let newPosition = WindowPositionCalculator.calculateCollapsedPosition(
            window: currentFrame,
            edge: edge,
            screen: mainScreen,
            exposedPixels: exposedPixels
        )
        
        do {
            try setPosition(newPosition)
            DockitLogger.shared.logInfo("窗口已移动到目标位置：\(newPosition)")
        } catch {
            DockitLogger.shared.logError("停靠窗口失败", error: error)
            Task { @MainActor in
                NotificationHelper.show(
                    type: .error,
                    title: "停靠窗口失败",
                    windowIcon: NotificationHelper.getAppIconForWindow(self)
                )
            }
        }
    }
    
    func expandTo(_ edge: DockEdge) {
        guard let currentFrame = try? frame() else {
            DockitLogger.shared.logError("无法获取窗口信息")
            return
        }
        
        // 只使用主屏幕
        guard let mainScreen = NSScreen.main else {
            DockitLogger.shared.logError("无法获取主屏幕")
            return
        }
        
        let newPosition = WindowPositionCalculator.calculateExpandedPosition(
            window: currentFrame,
            edge: edge,
            screen: mainScreen
        )
        
        do {
            try setPosition(newPosition)
            DockitLogger.shared.logInfo("窗口已展开到目标位置：\(newPosition)")
        } catch {
            DockitLogger.shared.logError("展开窗口失败", error: error)
            Task { @MainActor in
                NotificationHelper.show(
                    type: .error,
                    title: "展开窗口失败",
                    windowIcon: NotificationHelper.getAppIconForWindow(self)
                )
            }
        }
    }

    func safeTitle() -> String {
        return (try? title()) ?? ""
    }
}
