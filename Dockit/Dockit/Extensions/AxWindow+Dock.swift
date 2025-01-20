import AppKit
import Foundation
import SwiftUI
// import DynamicNotchKit
import NotchNotification

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
        guard let currentFrame = try? frame(),
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(currentFrame) })
        else {
            DockitLogger.shared.logError("无法获取窗口或屏幕信息")
            return
        }
        
        let newFrame = calculateDockFrame(
            currentFrame: currentFrame,
            edge: edge,
            screen: screen,
            exposedPixels: exposedPixels
        )
        
        do {
            try setPosition(newFrame.origin)
            DockitLogger.shared.logInfo("窗口已移动到目标位置：\(newFrame.origin)")
        } catch {
            DockitLogger.shared.logError("停靠窗口失败", error: error)
            NotificationHelper.show(
                type: .error,
                title: "停靠窗口失败"
            )
        }
    }
    
    private func calculateDockFrame(
        currentFrame: CGRect,
        edge: DockEdge,
        screen: NSScreen,
        exposedPixels: CGFloat
    ) -> CGRect {
        let coordinator = GlobalCoordinateSystem.shared
        let targetScreen = coordinator.getScreen(for: currentFrame) ?? screen
        var newFrame = currentFrame
        
        // 将窗口坐标转换为全局坐标
        let globalFrame = coordinator.calculateGlobalFrame(currentFrame, for: targetScreen)
        
        switch edge {
        case .left:
            newFrame.origin.x = targetScreen.frame.minX - currentFrame.width + exposedPixels
        case .right:
            newFrame.origin.x = targetScreen.frame.maxX - exposedPixels
        }
        
        // 将新位置转换回本地坐标
        let localFrame = coordinator.calculateLocalFrame(newFrame, for: targetScreen)
        return localFrame
    }

    func safeTitle() -> String {
        return (try? title()) ?? ""
    }
}
