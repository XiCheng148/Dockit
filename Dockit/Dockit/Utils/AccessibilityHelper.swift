import AppKit
import Combine
// import DynamicNotchKit
import SwiftUI
import NotchNotification

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
                // let notch = DynamicNotchInfo(
                //     icon: Image(systemName: "accessibility.fill"),
                //     title: "辅助功能",
                //     description: "Dockit 辅助权限已获取"
                // )
                // notch.show(for: 3)
                NotchNotification.present(
                    leadingView: Rectangle().hidden().frame(width: 4),
                    bodyView: HStack(spacing: 16) {
                        Image(systemName: "accessibility.fill").font(.system(size: 28))
                        Text("辅助功能权限已获取").font(.system(size: 16))
                    }.frame(width: 220),
                    interval: 2
                )
            }
        }
    }
} 
