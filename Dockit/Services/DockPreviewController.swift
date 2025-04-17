import AppKit
import SwiftUI
import Defaults

class DockPreviewController {
    static let shared = DockPreviewController()
    
    private var windowController: NSWindowController?
    private var autoCloseTimer: Timer?
    
    // 定义动画持续时间常量
    private let animationDuration: TimeInterval = 0.15
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
    
    func showAnimatedTransition(initialFrame: CGRect, targetFrame: CGRect) {
        guard isPreviewEnabled else { return }
        
        // 取消之前的定时器并关闭已有窗口
        autoCloseTimer?.invalidate()
        forceClosePreviewWindow()
        
        // 只使用主屏幕
        guard let mainScreen = NSScreen.main else { return }
        
        createPreviewWindow(initialFrame: initialFrame, targetFrame: targetFrame)
    }
    
    public func calculateTargetFrame(window: CGRect, edge: DockEdge, screen: NSScreen) -> CGRect {
        let targetPosition = WindowPositionCalculator.calculateCollapsedPosition(
            window: window,
            edge: edge,
            screen: screen,
            exposedPixels: Double(Defaults[.exposedPixels])
        )
        
        return CGRect(origin: targetPosition, size: window.size)
    }
    
    private func createPreviewWindow(initialFrame: CGRect, targetFrame: CGRect) {
        guard let mainScreen = NSScreen.main else { return }
        
        // 使用统一的坐标转换方法
        let convertedInitialFrame = initialFrame.convert(from: .accessibility, to: .flipped, in: mainScreen)
        let convertedTargetFrame = targetFrame.convert(from: .accessibility, to: .flipped, in: mainScreen)
        
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
