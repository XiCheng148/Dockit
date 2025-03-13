import AppKit
import SwiftUI
import Defaults

class DockPreviewController {
    static let shared = DockPreviewController()
    
    private var windowController: NSWindowController?
    private var closeTimer: Timer?
    
    private var isPreviewEnabled: Bool {
        return Defaults[.showPreview]
    }
    
    deinit {
        closePreviewWindow()
        closeTimer?.invalidate()
        closeTimer = nil
    }
    
    private init() {}
    
    func showPreview(for edge: DockEdge, window: CGRect) {
        guard isPreviewEnabled else { return }
        
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(window) }) else { return }
        
        let initialFrame = window
        let targetFrame = calculateTargetFrame(window: window, edge: edge, screen: screen)
        
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
        closePreviewWindow()
        
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
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(convertedTargetFrame, display: true)
            }, completionHandler: { [weak self] in
                self?.closePreviewWindow()
            })
        }
    }
    
    func closePreviewWindow() {
        closeTimer?.invalidate()
        closeTimer = nil
        
        guard let panel = windowController?.window else { return }
        
        weak var weakController = windowController
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.contentView = nil
            weakController?.close()
            weakController = nil
            self.windowController = nil
        })
    }
} 
