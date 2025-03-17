import AppKit
import SwiftUI
import Defaults

class DockPreviewController {
    static let shared = DockPreviewController()
    
    private var windowController: NSWindowController?
    private var autoCloseTimer: Timer?
    
    // 定义动画持续时间常量
    private let animationDuration: TimeInterval = 0.6
    // 定义定时器额外缓冲时间
    private let timerBuffer: TimeInterval = 0.1
    
    private var isPreviewEnabled: Bool {
        return Defaults[.showPreview]
    }
    
    deinit {
        autoCloseTimer?.invalidate()
        forceClosePreviewWindow()
    }
    
    private init() {}
    
    func showPreview(for edge: DockEdge, window: CGRect) {
        guard isPreviewEnabled else { return }
        
        // 取消之前的定时器并关闭已有窗口
        autoCloseTimer?.invalidate()
        forceClosePreviewWindow()
        
        // 只使用主屏幕
        guard let mainScreen = NSScreen.main else { return }
        
        let initialFrame = window
        let targetFrame = calculateTargetFrame(window: window, edge: edge, screen: mainScreen)
        
        createPreviewWindow(initialFrame: initialFrame, targetFrame: targetFrame)
    }
    
    private func calculateTargetFrame(window: CGRect, edge: DockEdge, screen: NSScreen) -> CGRect {
        let targetPosition = WindowPositionCalculator.calculateCollapsedPosition(
            window: window,
            edge: edge,
            screen: screen,
            exposedPixels: Double(Defaults[.exposedPixels])
        )
        
        return CGRect(origin: targetPosition, size: window.size)
    }
    
    private func createPreviewWindow(initialFrame: CGRect, targetFrame: CGRect) {
        let screenFrame = NSScreen.main?.frame ?? NSScreen.screens.first!.frame
        
        let convertedInitialFrame = CGRect(
            x: initialFrame.origin.x,
            y: screenFrame.height - initialFrame.origin.y - initialFrame.height,
            width: initialFrame.width,
            height: initialFrame.height
        )
        
        let convertedTargetFrame = CGRect(
            x: targetFrame.origin.x,
            y: screenFrame.height - targetFrame.origin.y - targetFrame.height,
            width: targetFrame.width,
            height: targetFrame.height
        )
        
        autoreleasepool {
            let panel = NSPanel(
                contentRect: convertedInitialFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.level = .floating
            panel.collectionBehavior = .canJoinAllSpaces
            panel.ignoresMouseEvents = true
            
            let hostingView = NSHostingView(rootView: DockPreviewView())
            panel.contentView = hostingView
            
            panel.orderFrontRegardless()
            windowController = NSWindowController(window: panel)
            
            // 设置自动关闭定时器，确保比动画时间长
            setupAutoCloseTimer()
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(convertedTargetFrame, display: true)
            }, completionHandler: nil)
        }
    }
    
    private func forceClosePreviewWindow() {
        if let panel = windowController?.window, panel.isVisible {
            panel.contentView = nil
            panel.close()
        }
        windowController = nil
    }
    
    private func setupAutoCloseTimer() {
        autoCloseTimer?.invalidate()
        
        // 确保定时器时间始终比动画时间长一点
        let timerDuration = animationDuration + timerBuffer
        
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: timerDuration, repeats: false) { [weak self] _ in
            self?.forceClosePreviewWindow()
        }
    }
} 
