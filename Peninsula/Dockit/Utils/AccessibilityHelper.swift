import AppKit
import Combine

class AccessibilityHelper {
    static let shared = AccessibilityHelper()
    
    let accessibilityStatusPublisher = PassthroughSubject<Bool, Never>()
    private var checkTimer: Timer?
    
    func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // 开始监听权限变化
        startAccessibilityCheck()
    }
    
    private func startAccessibilityCheck() {
        // 停止现有的计时器
        checkTimer?.invalidate()
        
        // 创建新的计时器
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let status = self.checkAccessibility()
            self.accessibilityStatusPublisher.send(status)
            
            // 如果获得了权限，停止检查
            if status {
                self.checkTimer?.invalidate()
                self.checkTimer = nil
            }
        }
    }
} 
