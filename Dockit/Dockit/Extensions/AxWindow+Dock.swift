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
            // let dynamicNotch = DynamicNotchInfo (
            //     icon: Image(systemName: "xmark.circle.fill"),
            //     title: "停靠窗口失败",
            //     description: "停靠窗口到\(edge == .left ? "左" : "右")边失败"
            // )
            // dynamicNotch.show(for: 3)
            NotchNotification.present(
                leadingView: Rectangle().hidden().frame(width: 4),
                bodyView: HStack() {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 28)).padding(.trailing, 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("停靠窗口失败").lineLimit(1).font(.system(size: 14)).bold()
                    }
                },
            interval: 2
        )
        }
    }
    
    private func calculateDockFrame(
        currentFrame: CGRect,
        edge: DockEdge,
        screen: NSScreen,
        exposedPixels: CGFloat
    ) -> CGRect {
        // 获取窗口所在屏幕
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(currentFrame) }) ?? screen
        var newFrame = currentFrame
        
        switch edge {
        case .left:
            newFrame.origin.x = screen.frame.minX - currentFrame.width + exposedPixels
        case .right:
            newFrame.origin.x = screen.frame.maxX - exposedPixels
        }
        
        return newFrame
    }

    func safeTitle() -> String {
        return (try? title()) ?? ""
    }
} 
