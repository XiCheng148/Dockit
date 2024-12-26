import AppKit
import Foundation

extension AxWindow {
    func setPosition(_ position: CGPoint) throws {
        var point = position
        let axValue = AXValueCreate(.cgPoint, &point)!
        let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axValue)
        if result != .success {
            throw AxError.runtimeError
        }
    }
    
    func setSize(_ size: CGSize) throws {
        var cgSize = size
        let axValue = AXValueCreate(.cgSize, &cgSize)!
        let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axValue)
        if result != .success {
            throw AxError.runtimeError
        }
    }

    func dockTo(_ edge: DockEdge, exposedPixels: CGFloat) {
        guard let currentFrame = try? frame(),
              let screen = NSScreen.main 
        else { return }
        
        let newFrame = calculateDockFrame(
            currentFrame: currentFrame,
            edge: edge,
            screen: screen,
            exposedPixels: exposedPixels
        )
        
        try? setPosition(newFrame.origin)
        // try? setSize(newFrame.size)
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
