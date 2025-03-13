import SwiftUI
import NotchNotification
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
    
    private static func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }
    
    static func show(
        type: NotificationType,
        title: String,
        description: String? = nil,
        interval: TimeInterval = 2
    ) {
        let truncatedTitle = truncateText(title, maxLength: maxTitleLength)
        
        // 获取应用图标并调整大小
        let appIcon = NSImage(named: NSImage.applicationIconName) ?? NSImage()
        let resizedIcon = resizeImage(appIcon, to: CGSize(width: 18, height: 18))
        
        NotchNotification.present(
            // 使用调整过大小的图标
            leadingView: Image(nsImage: resizedIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18),
            trailingView: Image(systemName: type.icon),
            bodyView: HStack() {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(truncatedTitle)
                            .font(.system(size: 14))
                            .bold()
                        if let description = description {
                            Text(description)
                                .font(.system(size: 12))
                        }
                    }
                }
            },
            interval: interval
        )
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
