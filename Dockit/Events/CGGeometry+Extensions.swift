//
//  CGGeometry+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI
import AppKit

// MARK: - 坐标系统类型
enum CoordinateSystem {
    case screen      // 屏幕坐标系 (0,0在左下角)
    case window      // 窗口坐标系 (0,0在左下角)
    case flipped     // 翻转坐标系 (0,0在左上角)
    case accessibility // 辅助功能坐标系 (与屏幕坐标系相同)
}

// MARK: - CGFloat扩展
extension CGFloat {
    func approximatelyEquals(to comparison: CGFloat, tolerance: CGFloat = 10) -> Bool {
        abs(self - comparison) < tolerance
    }
}

// MARK: - CGPoint扩展
extension CGPoint {
    // 计算两点之间的角度
    func angle(to comparisonPoint: CGPoint) -> CGFloat {
        let originX = comparisonPoint.x - x
        let originY = comparisonPoint.y - y
        let bearingRadians = -atan2f(Float(originY), Float(originX))
        return CGFloat(bearingRadians)
    }
    
    // 计算两点之间距离的平方
    func distanceSquared(to comparisonPoint: CGPoint) -> CGFloat {
        return (x - comparisonPoint.x) * (x - comparisonPoint.x) +
               (y - comparisonPoint.y) * (y - comparisonPoint.y)
    }
    
    // 计算两点之间的距离
    func distance(to comparisonPoint: CGPoint) -> CGFloat {
        return sqrt(distanceSquared(to: comparisonPoint))
    }
    
    // 翻转Y坐标 (屏幕坐标系 <-> 翻转坐标系)
    func flipY(maxY: CGFloat) -> CGPoint {
        return CGPoint(x: x, y: maxY - y)
    }
    
    // 使用屏幕高度翻转Y坐标
    func flipY(screen: NSScreen) -> CGPoint {
        return flipY(maxY: screen.frame.maxY)
    }
    
    // 判断两点是否近似相等
    func approximatelyEqual(to point: CGPoint, tolerance: CGFloat = 10) -> Bool {
        return abs(x - point.x) < tolerance && abs(y - point.y) < tolerance
    }
    
    // 转换坐标系统
    func convert(from source: CoordinateSystem, to destination: CoordinateSystem, in screen: NSScreen? = NSScreen.main) -> CGPoint {
        guard let screen = screen else { return self }
        
        switch (source, destination) {
        case (.screen, .flipped), (.accessibility, .flipped):
            return flipY(screen: screen)
        case (.flipped, .screen), (.flipped, .accessibility):
            return flipY(screen: screen)
        case (.window, .screen), (.window, .accessibility):
            return self // 窗口坐标系与屏幕坐标系相同
        case (.screen, .window), (.accessibility, .window):
            return self // 屏幕坐标系与窗口坐标系相同
        default:
            return self // 相同坐标系统不需要转换
        }
    }
    
    // 获取相对于指定屏幕的坐标
    func relativeToScreen(_ screen: NSScreen) -> CGPoint {
        return CGPoint(
            x: x - screen.frame.minX,
            y: y - screen.frame.minY
        )
    }
}

// MARK: - CGSize扩展
extension CGSize {
    var area: CGFloat {
        return width * height
    }
    
    func approximatelyEqual(to size: CGSize, tolerance: CGFloat = 10) -> Bool {
        return abs(width - size.width) < tolerance && abs(height - size.height) < tolerance
    }
    
    // 创建一个居中的矩形
    func center(inside parentRect: CGRect) -> CGRect {
        let parentRectCenter = parentRect.center
        let newX = parentRectCenter.x - width / 2
        let newY = parentRectCenter.y - height / 2
        
        return CGRect(
            x: newX,
            y: newY,
            width: width,
            height: height
        )
    }
}

// MARK: - CGRect扩展
extension CGRect {
    // 翻转Y坐标 (屏幕坐标系 <-> 翻转坐标系)
    func flipY(screen: NSScreen) -> CGRect {
        return flipY(maxY: screen.frame.maxY)
    }
    
    func flipY(maxY: CGFloat) -> CGRect {
        return CGRect(
            x: minX,
            y: maxY - self.maxY,
            width: width,
            height: height
        )
    }
    
    // 添加内边距
    func padding(_ sides: Edge.Set, _ amount: CGFloat) -> CGRect {
        var rect = self
        
        if sides.contains(.top) {
            rect.origin.y += amount
            rect.size.height -= amount
        }
        
        if sides.contains(.bottom) {
            rect.size.height -= amount
        }
        
        if sides.contains(.leading) {
            rect.origin.x += amount
            rect.size.width -= amount
        }
        
        if sides.contains(.trailing) {
            rect.size.width -= amount
        }
        
        return rect
    }
    
    // 判断两个矩形是否近似相等
    func approximatelyEqual(to rect: CGRect, tolerance: CGFloat = 10) -> Bool {
        return origin.approximatelyEqual(to: rect.origin, tolerance: tolerance) &&
               size.approximatelyEqual(to: rect.size, tolerance: tolerance)
    }
    
    // 将矩形推入另一个矩形内部
    func pushInside(_ rect2: CGRect) -> CGRect {
        var result = self
        
        if result.minX < rect2.minX {
            result.origin.x = rect2.minX
        }
        
        if result.minY < rect2.minY {
            result.origin.y = rect2.minY
        }
        
        if result.maxX > rect2.maxX {
            result.origin.x = rect2.maxX - result.width
        }
        
        if result.maxY > rect2.maxY {
            result.origin.y = rect2.maxY - result.height
        }
        
        return result
    }
    
    // 获取矩形的四个角点
    var topLeftPoint: CGPoint {
        return CGPoint(x: minX, y: minY)
    }
    
    var topRightPoint: CGPoint {
        return CGPoint(x: maxX, y: minY)
    }
    
    var bottomLeftPoint: CGPoint {
        return CGPoint(x: minX, y: maxY)
    }
    
    var bottomRightPoint: CGPoint {
        return CGPoint(x: maxX, y: maxY)
    }
    
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    // 创建内嵌矩形，保持最小尺寸
    func inset(by amount: CGFloat, minSize: CGSize) -> CGRect {
        let insettedWidth = max(minSize.width, width - 2 * amount)
        let insettedHeight = max(minSize.height, height - 2 * amount)
        
        let newX = midX - insettedWidth / 2
        let newY = midY - insettedHeight / 2
        
        return CGRect(
            x: newX,
            y: newY,
            width: insettedWidth,
            height: insettedHeight
        )
    }
    
    // 获取与另一个矩形接触的边
    func getEdgesTouchingBounds(_ rect2: CGRect) -> Edge.Set {
        var result: Edge.Set = []
        
        if minX.approximatelyEquals(to: rect2.minX) {
            result.insert(.leading)
        }
        
        if minY.approximatelyEquals(to: rect2.minY) {
            result.insert(.top)
        }
        
        if maxX.approximatelyEquals(to: rect2.maxX) {
            result.insert(.trailing)
        }
        
        if maxY.approximatelyEquals(to: rect2.maxY) {
            result.insert(.bottom)
        }
        
        return result
    }
    
    // 转换坐标系统
    func convert(from source: CoordinateSystem, to destination: CoordinateSystem, in screen: NSScreen? = NSScreen.main) -> CGRect {
        guard let screen = screen else { return self }
        
        switch (source, destination) {
        case (.screen, .flipped), (.accessibility, .flipped):
            return flipY(screen: screen)
        case (.flipped, .screen), (.flipped, .accessibility):
            return flipY(screen: screen)
        default:
            return self // 相同坐标系统或不需要转换的情况
        }
    }
    
    // 获取相对于指定屏幕的矩形
    func relativeToScreen(_ screen: NSScreen) -> CGRect {
        return CGRect(
            x: origin.x - screen.frame.minX,
            y: origin.y - screen.frame.minY,
            width: width,
            height: height
        )
    }
    
    // 计算矩形在屏幕上的可见部分
    func visiblePortion(in screen: NSScreen) -> CGFloat {
        let intersection = intersection(screen.frame)
        if intersection.isEmpty { return 0 }
        
        let intersectionArea = intersection.width * intersection.height
        let totalArea = width * height
        
        return intersectionArea / totalArea
    }
    
    // 判断矩形是否大部分在屏幕外
    func isLargelyOffscreen(threshold: CGFloat = 0.3) -> Bool {
        let screens = NSScreen.screens
        return screens.allSatisfy { screen in
            visiblePortion(in: screen) < threshold
        }
    }
}

// MARK: - NSScreen扩展
extension NSScreen {
    // 获取包含指定点的屏幕
    static func containing(_ point: NSPoint) -> NSScreen? {
        return NSScreen.screens.first { screen in
            screen.frame.contains(point)
        }
    }
    
    // 获取包含指定矩形的屏幕
    static func containing(_ rect: CGRect) -> NSScreen? {
        return NSScreen.screens.first { screen in
            screen.frame.intersects(rect)
        }
    }
    
    // 获取与指定矩形相交最多的屏幕
    static func mostIntersecting(with rect: CGRect) -> NSScreen? {
        var maxIntersectionArea: CGFloat = 0
        var resultScreen: NSScreen? = nil
        
        for screen in NSScreen.screens {
            let intersection = screen.frame.intersection(rect)
            let area = intersection.width * intersection.height
            
            if area > maxIntersectionArea {
                maxIntersectionArea = area
                resultScreen = screen
            }
        }
        
        return resultScreen ?? NSScreen.main
    }
}
