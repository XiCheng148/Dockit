import AppKit
import Foundation

class DockitEventMonitor {
    var onMouseMoved: ((NSPoint) -> Void)?
    private var mouseMonitor: Any?
    private var lastExecutionTime: Date = .distantPast
    
    // 使用 FPS 来控制采样率
    // 4(节能)、10(平衡)、30(流畅)、60(跟手)、120(丝滑)
    private var fps: Double = 30
    
    private var throttleInterval: TimeInterval {
        return 1.0 / fps  // 1000ms / 60 ≈ 16.7ms
    }
    
    func startMonitoring() {
        guard mouseMonitor == nil else { return }
        DockitLogger.shared.logInfo("开始监控鼠标移动 (FPS: \(Int(fps)))")
        
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            if now.timeIntervalSince(self.lastExecutionTime) >= self.throttleInterval {
                let location = NSEvent.mouseLocation
                DockitLogger.shared.logInfo("鼠标位置: (\(Int(location.x)), \(Int(location.y)))")
                self.onMouseMoved?(location)
                self.lastExecutionTime = now
            }
        }
    }
    
    func stopMonitoring() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
            DockitLogger.shared.logInfo("停止监控鼠标移动")
        }
    }
    
    func updateFPS(_ newFPS: Double) {
        fps = newFPS
        // 如果正在监听，重启监听以应用新的 FPS
        if mouseMonitor != nil {
            stopMonitoring()
            startMonitoring()
        }
    }
    
    deinit {
        stopMonitoring()
    }
} 
