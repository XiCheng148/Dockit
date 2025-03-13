import AppKit
import Foundation

struct WindowPositionCalculator {
    // 计算窗口收起状态的位置（停靠位置）
    static func calculateCollapsedPosition(
        window: CGRect,
        edge: DockEdge,
        screen: NSScreen,
        exposedPixels: CGFloat
    ) -> CGPoint {
        let coordinator = GlobalCoordinateSystem.shared
        let targetScreen = coordinator.getScreen(for: window) ?? screen
        
        let newPosition: CGPoint
        
        switch edge {
        case .left:
            newPosition = CGPoint(
                x: targetScreen.frame.minX - window.width + exposedPixels,
                y: window.origin.y
            )
        case .right:
            newPosition = CGPoint(
                x: targetScreen.frame.maxX - exposedPixels,
                y: window.origin.y
            )
        }
        
        return newPosition
    }
    
    // 计算窗口展开状态的位置
    static func calculateExpandedPosition(
        window: CGRect,
        edge: DockEdge,
        screen: NSScreen
    ) -> CGPoint {
        let coordinator = GlobalCoordinateSystem.shared
        let targetScreen = coordinator.getScreen(for: window) ?? screen
        
        let newPosition: CGPoint
        
        switch edge {
        case .left:
            newPosition = CGPoint(
                x: targetScreen.frame.minX,
                y: window.origin.y
            )
        case .right:
            newPosition = CGPoint(
                x: targetScreen.frame.maxX - window.width,
                y: window.origin.y
            )
        }
        
        return newPosition
    }
    
    // 判断当前窗口位置是否为收起状态
    static func isCollapsedPosition(
        window: CGRect,
        edge: DockEdge,
        screen: NSScreen,
        exposedPixels: CGFloat,
        threshold: CGFloat = 5.0
    ) -> Bool {
        let expectedPosition = calculateCollapsedPosition(
            window: window,
            edge: edge,
            screen: screen,
            exposedPixels: exposedPixels
        )
        
        return abs(window.origin.x - expectedPosition.x) <= threshold
    }
    
    // 判断当前窗口位置是否为展开状态
    static func isExpandedPosition(
        window: CGRect,
        edge: DockEdge,
        screen: NSScreen,
        threshold: CGFloat = 5.0
    ) -> Bool {
        let expectedPosition = calculateExpandedPosition(
            window: window,
            edge: edge,
            screen: screen
        )
        
        return abs(window.origin.x - expectedPosition.x) <= threshold
    }
    
    // 根据窗口当前的位置和参数，计算下一个位置（如果是展开状态则计算收起位置，反之亦然）
    static func calculateNextPosition(
        window: CGRect,
        edge: DockEdge,
        screen: NSScreen,
        exposedPixels: CGFloat
    ) -> CGPoint {
        if isExpandedPosition(window: window, edge: edge, screen: screen) {
            return calculateCollapsedPosition(window: window, edge: edge, screen: screen, exposedPixels: exposedPixels)
        } else {
            return calculateExpandedPosition(window: window, edge: edge, screen: screen)
        }
    }
} 
