import AppKit
import Foundation

class DockitEventMonitor {
    var onMouseMoved: ((NSPoint) -> Void)?
    private var mouseLocationTimer: Timer?
    
    func startMonitoring() {
        mouseLocationTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            self?.checkMouseLocation()
        }
    }
    
    private func checkMouseLocation() {
        let location = NSEvent.mouseLocation
        onMouseMoved?(location)
    }
    
    deinit {
        mouseLocationTimer?.invalidate()
    }
} 
