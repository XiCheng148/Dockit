import SwiftUI
import DynamicNotchKit
import AppKit

enum NotificationType {
    case success
    case error
    case warning
    case info
    case custom(String)
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .custom(let iconName): return iconName
        }
    }
}

class NotificationHelper {
    private static let maxTitleLength = 20
    // 创建一个单例实例以便重用
    static var dynamicNotch = DynamicNotchInfo(title: "Airpods")
    
    private static func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }
    
    @MainActor static func show(
        type: NotificationType,
        title: String,
        description: String? = nil,
        interval: TimeInterval = 2
    ) {
        let truncatedTitle = truncateText(title, maxLength: maxTitleLength)
        
        // 获取应用图标并调整大小
        let appIcon = NSImage(named: NSImage.applicationIconName) ?? NSImage()
        let resizedIcon = resizeImage(appIcon, to: CGSize(width: 18, height: 18))
        
        // 使用DynamicNotchKit的setContent方法
        dynamicNotch.setContent(
            icon: Image(nsImage: resizedIcon),
            title: truncatedTitle,
            description: description
        )
        
        // 显示通知，设置显示时间
        dynamicNotch.show(for: interval)
    }
    
    // 辅助函数：调整 NSImage 大小
    private static func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy,
                  fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
} 
