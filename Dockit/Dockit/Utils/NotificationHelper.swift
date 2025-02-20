import SwiftUI
import NotchNotification

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
        
        NotchNotification.present(
            leadingView: Rectangle().hidden().frame(width: 4),
            bodyView: HStack() {
                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .padding(.trailing, 16)
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
} 