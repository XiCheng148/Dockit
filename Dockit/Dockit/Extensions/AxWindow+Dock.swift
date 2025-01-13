import AppKit
import Foundation
import SwiftUI
import DynamicNotchKit

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
              let screen = NSScreen.main 
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
            let dynamicNotch = DynamicNotchInfo (
                icon: Image(systemName: "xmark.circle.fill"),
                title: "停靠窗口失败",
                description: "停靠窗口到\(edge == .left ? "左" : "右")边失败"
            )
            dynamicNotch.show(for: 3)
        }
    }
    
    private func calculateDockFrame(
        currentFrame: CGRect,
        edge: DockEdge,
        screen: NSScreen,
        exposedPixels: CGFloat
    ) -> CGRect {
        var newFrame = currentFrame
        
        switch edge {
        case .left:
            newFrame.origin.x = -currentFrame.width + exposedPixels
        case .right:
            newFrame.origin.x = screen.frame.width - exposedPixels
        }
        
        return newFrame
    }
} 
