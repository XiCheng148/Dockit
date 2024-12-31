import Foundation

enum LogType {
    case action
    case info
    case error
    
    var prefix: String {
        switch self {
        case .action: return "🎯"
        case .info: return "ℹ️"
        case .error: return "⚠️"
        }
    }
}

class DockitLogger {
    static let shared = DockitLogger()
    
    private var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    private init() {}
    
    private func log(_ type: LogType, _ message: String) {
        guard isEnabled else { return }
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] \(type.prefix) \(message)")
    }
    
    // MARK: - 快捷键事件
    func logShortcut(_ edge: DockEdge) {
        log(.action, "快捷键：⌘⇧\(edge == .left ? "←" : "→")")
    }
    
    func logUndockAllShortcut() {
        log(.action, "快捷键：⌘⇧H")
    }
    
    // MARK: - 窗口事件
    func logWindowDocked(_ title: String?, edge: DockEdge, frame: CGRect?) {
        if let title = title, let frame = frame {
            log(.action, "停靠窗口「\(title)」-> \(edge == .left ? "左" : "右") [位置: \(Int(frame.origin.x)),\(Int(frame.origin.y)) 大小: \(Int(frame.width))×\(Int(frame.height))]")
        }
    }
    
    func logWindowShown(_ title: String?, frame: CGRect?) {
        if let title = title, let frame = frame {
            log(.action, "展开窗口「\(title)」[位置: \(Int(frame.origin.x)),\(Int(frame.origin.y))]")
        }
    }
    
    func logWindowHidden(_ title: String?, frame: CGRect?) {
        if let title = title, let frame = frame {
            log(.action, "收起窗口「\(title)」[位置: \(Int(frame.origin.x)),\(Int(frame.origin.y))]")
        }
    }
    
    func logWindowUndocked(_ title: String?, reason: UndockReason, frame: CGRect?) {
        let reasonText = switch reason {
        case .userAction: "快捷键"
        case .windowClosed: "窗口关闭"
        case .dragDistance: "拖拽超出"
        }
        if let title = title, let frame = frame {
            log(.action, "取消停靠「\(title)」- \(reasonText) [位置: \(Int(frame.origin.x)),\(Int(frame.origin.y))]")
        }
    }
    
    func logWindowMoved(_ title: String?, distance: CGFloat, frame: CGRect?) {
        if let title = title, let frame = frame {
            log(.info, "窗口移动「\(title)」- 距离: \(Int(distance))px [位置: \(Int(frame.origin.x)),\(Int(frame.origin.y))]")
        }
    }
    
    // MARK: - 错误日志
    func logError(_ message: String, error: Error? = nil) {
        if let error = error {
            log(.error, "\(message) [\(error.localizedDescription)]")
        } else {
            log(.error, message)
        }
    }
    
    // MARK: - 信息日志
    func logInfo(_ message: String) {
        log(.info, message)
    }
}

enum UndockReason {
    case userAction   // 用户手动取消（快捷键等）
    case windowClosed // 窗口关闭
    case dragDistance // 拖拽距离超过阈值
} 
