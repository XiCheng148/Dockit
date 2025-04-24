import AppKit
import SwiftUI
import Defaults

class DockPreviewController {
    static let shared = DockPreviewController()
    
    private var windowController: NSWindowController?
    private var autoCloseTimer: Timer?
    // 添加标记当前是否有正在进行的操作
    private var isAnimationInProgress = false
    // 添加保存当前动画的完成回调，以便能够取消
    private var currentAnimationCompletion: (() -> Void)?
    
    // 定义动画持续时间常量
    private let animationDuration: TimeInterval = 0.3
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
    
    // 取消当前正在进行的动画和操作
    func cancelCurrentAnimation() {
        // 取消自动关闭计时器
        autoCloseTimer?.invalidate()
        
        // 清除当前的完成回调（不执行）
        currentAnimationCompletion = nil
        
        // 关闭预览窗口
        forceClosePreviewWindow()
        
        // 重置动画状态
        isAnimationInProgress = false
    }
    
    func showAnimatedTransition(initialFrame: CGRect, targetFrame: CGRect, completion: (() -> Void)? = nil) {
        // 如果已有动画在进行中，先取消它
        if isAnimationInProgress {
            cancelCurrentAnimation()
        }
        
        // 更新状态和保存完成回调
        isAnimationInProgress = true
        currentAnimationCompletion = completion
        
        guard isPreviewEnabled else { 
            // 即使没有预览，也要执行完成回调并重置状态
            isAnimationInProgress = false
            currentAnimationCompletion = nil
            completion?()
            return 
        }
        
        // 取消之前的定时器并关闭已有窗口
        autoCloseTimer?.invalidate()
        forceClosePreviewWindow()
        
        // 只使用主屏幕
        guard let mainScreen = NSScreen.main else { 
            isAnimationInProgress = false
            currentAnimationCompletion = nil
            completion?()
            return 
        }
        
        createPreviewWindow(initialFrame: initialFrame, targetFrame: targetFrame, completion: completion)
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
    
    private func createPreviewWindow(initialFrame: CGRect, targetFrame: CGRect, completion: (() -> Void)? = nil) {
        guard let mainScreen = NSScreen.main else { 
            isAnimationInProgress = false
            currentAnimationCompletion = nil
            completion?()
            return 
        }
        
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
            }, completionHandler: {
                // 动画完成后执行回调并重置状态
                self.isAnimationInProgress = false
                // 保存本地变量，以防在执行过程中被另一个操作清除
                let savedCompletion = self.currentAnimationCompletion
                self.currentAnimationCompletion = nil
                savedCompletion?()
            })
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
            guard let self = self else { return }
            self.forceClosePreviewWindow()
        }
    }
} 
