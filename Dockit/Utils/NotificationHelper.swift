import SwiftUI
import DynamicNotchKit
import AppKit
import Defaults

enum NotificationType {
    case success
    case error
    case warning
    case info
    case dockLeft
    case dockRight
    case custom(String)
    
    var actionIcon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .dockLeft: return "arrow.left.circle.fill"
        case .dockRight: return "arrow.right.circle.fill"
        case .custom(let iconName): return iconName
        }
    }
}

class NotificationHelper {
    private static let maxTitleLength = 26
    
    // 创建三个不同样式的DynamicNotch实例
    private static let autoNotch = DynamicNotch<AnyView>(style: .auto) {
        AnyView(EmptyView())
    }
    
    private static let notchStyleNotch = DynamicNotch<AnyView>(style: .notch) {
        AnyView(EmptyView())
    }
    
    private static let floatingNotch = DynamicNotch<AnyView>(style: .floating) {
        AnyView(EmptyView())
    }
    
    // 根据用户设置获取对应的DynamicNotch实例
    private static var currentNotch: DynamicNotch<AnyView> {
        let styleString = Defaults[.notchStyle]
        switch styleString {
        case "notch": return notchStyleNotch
        case "floating": return floatingNotch
        default: return autoNotch
        } 
    }
    
    private static func truncateText(_ text: String, maxLength: Int) -> String {
        // 首先替换所有换行符为空格
        let singleLineText = text.replacingOccurrences(of: "\n", with: " ")
                                 .replacingOccurrences(of: "\r", with: " ")
        
        // 移除多余的空格
        let normalizedText = singleLineText.replacingOccurrences(of: "  ", with: " ")
        
        if normalizedText.count <= maxLength {
            return normalizedText
        }
        return String(normalizedText.prefix(maxLength)) + "..."
    }
    
    static func show(
        type: NotificationType,
        title: String,
        description: String? = nil,
        interval: TimeInterval = 2,
        windowIcon: NSImage? = nil
    ) {
        Task { @MainActor in
            let truncatedTitle = truncateText(title, maxLength: maxTitleLength)
            
            // 使用传入的窗口图标，如果没有则使用应用图标
            let appIcon = windowIcon ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
            let resizedIcon = resizeImage(appIcon, to: CGSize(width: 36, height: 36))
            
            // 使用当前选中样式的DynamicNotch实例
            currentNotch.setContent {
                AnyView(
                    HStack {
                        Image(nsImage: resizedIcon)
                        Spacer()
                        VStack(alignment: .center) {
                            Text(truncatedTitle)
                                .font(.headline)
                            if let description = description {
                                Text(description)
                                    .font(.subheadline)
                            }
                        }
                        Spacer()
                        Image(systemName: type.actionIcon)
                            .font(.system(size: 32))
                    }
                )
            }
            
            // 显示通知，设置显示时间
            currentNotch.show(for: interval)
        }
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
    
    // 辅助函数：获取应用图标
    static func getAppIconForWindow(_ axWindow: AxWindow?) -> NSImage? {
        guard let axWindow = axWindow else { return nil }
        
        // 尝试获取窗口所属应用的PID
        if let pid = try? axWindow.pid() {
            // 通过PID获取运行中的应用
            if let app = NSRunningApplication(processIdentifier: pid) {
                return app.icon
            }
        }
        
        return nil
    }
} 
