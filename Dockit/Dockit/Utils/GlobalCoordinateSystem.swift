import AppKit
import Foundation

class GlobalCoordinateSystem {
    static let shared = GlobalCoordinateSystem()
    
    private init() {}
    
    // 将本地坐标转换为全局坐标
    func toGlobal(_ point: CGPoint, from screen: NSScreen) -> CGPoint {
        let mainScreen = NSScreen.main ?? screen
        let mainOrigin = mainScreen.frame.origin
        let screenOrigin = screen.frame.origin
        
        return CGPoint(
            x: point.x + (screenOrigin.x - mainOrigin.x),
            y: point.y + (screenOrigin.y - mainOrigin.y)
        )
    }
    
    // 将全局坐标转换为本地坐标
    func toLocal(_ point: CGPoint, for screen: NSScreen) -> CGPoint {
        let mainScreen = NSScreen.main ?? screen
        let mainOrigin = mainScreen.frame.origin
        let screenOrigin = screen.frame.origin
        
        return CGPoint(
            x: point.x - (screenOrigin.x - mainOrigin.x),
            y: point.y - (screenOrigin.y - mainOrigin.y)
        )
    }
    
    // 获取窗口所在的屏幕
    func getScreen(for frame: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        var maxIntersectionArea: CGFloat = 0
        var targetScreen: NSScreen? = nil
        
        for screen in screens {
            let intersection = screen.frame.intersection(frame)
            let area = intersection.width * intersection.height
            if area > maxIntersectionArea {
                maxIntersectionArea = area
                targetScreen = screen
            }
        }
        
        return targetScreen ?? NSScreen.main
    }
    
    // 计算窗口在全局坐标系中的位置
    func calculateGlobalFrame(_ frame: CGRect, for screen: NSScreen) -> CGRect {
        let origin = toGlobal(frame.origin, from: screen)
        return CGRect(origin: origin, size: frame.size)
    }
    
    // 计算窗口在本地坐标系中的位置
    func calculateLocalFrame(_ frame: CGRect, for screen: NSScreen) -> CGRect {
        let origin = toLocal(frame.origin, for: screen)
        return CGRect(origin: origin, size: frame.size)
    }
    
    // 判断两个坐标是否在同一屏幕上
    func isSameScreen(_ point1: CGPoint, _ point2: CGPoint) -> Bool {
        guard let screen1 = getScreen(for: CGRect(origin: point1, size: .zero)),
              let screen2 = getScreen(for: CGRect(origin: point2, size: .zero)) else {
            return false
        }
        return screen1 == screen2
    }
}
