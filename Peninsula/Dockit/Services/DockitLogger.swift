import Foundation

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
    
    func log(_ message: String) {
        guard isEnabled else { return }
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] \(message)")
    }
    
    // MARK: - 快捷键事件
    func logShortcut(_ edge: DockEdge) {
        log("⌨️ 快捷键触发：停靠到\(edge == .left ? "左" : "右")边缘")
    }
    
    func logUndockAllShortcut() {
        log("⌨️ 快捷键触发：取消所有停靠")
    }
    
    // MARK: - 窗口事件
    func logWindowDocked(_ title: String?, edge: DockEdge) {
        log("📌 窗口停靠：\(title ?? "未知窗口") -> \(edge == .left ? "左" : "右")边缘")
    }
    
    func logWindowShown(_ title: String?) {
        log("👀 窗口展开：\(title ?? "未知窗口")")
    }
    
    func logWindowHidden(_ title: String?) {
        log("🙈 窗口收起：\(title ?? "未知窗口")")
    }
    
    func logWindowUndocked(_ title: String?, reason: UndockReason) {
        let reasonText = switch reason {
        case .userAction: "用户手动取消"
        case .windowClosed: "窗口关闭"
        case .dragDistance: "拖拽距离超过阈值"
        }
        log("🔓 窗口取消停靠：\(title ?? "未知窗口") - 原因：\(reasonText)")
    }
    
    func logWindowMoved(_ title: String?, distance: CGFloat) {
        log("🔄 窗口移动：\(title ?? "未知窗口") - 距离：\(Int(distance))px")
    }
}

enum UndockReason {
    case userAction   // 用户手动取消（快捷键等）
    case windowClosed // 窗口关闭
    case dragDistance // 拖拽距离超过阈值
} 
