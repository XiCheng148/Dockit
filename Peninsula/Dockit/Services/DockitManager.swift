import AppKit
import Foundation
import SwiftUI

class DockitManager: ObservableObject {
    static let shared = DockitManager()
    
    @Published private(set) var dockedWindows: [DockedWindow] = []
    @Published var exposedPixels: Double = 10
    @Published var triggerAreaWidth: Double = 10
    @Published var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                undockAllWindows()
            }
        }
    }
    @Published var respectSpaces: Bool = true
    
    private let eventMonitor = DockitEventMonitor()
    
    private init() {
        setupEventMonitor()
    }
    
    func dockWindow(_ axWindow: AxWindow, to edge: DockEdge) {
        guard isEnabled else { return }
        
        guard let app = NSWorkspace.shared.frontmostApplication,
              let window = Windows.shared.inner.first(where: { $0.axWindow == axWindow }) else { return }
        
        let dockedWindow = DockedWindow(axWindow: axWindow, edge: edge)
        dockedWindows.append(dockedWindow)
        
        DockitLogger.shared.logWindowDocked(try? axWindow.title(), edge: edge)
        axWindow.dockTo(edge, exposedPixels: exposedPixels)
    }
    
    func undockWindow(_ id: UUID, reason: UndockReason = .userAction) {
        guard let window = dockedWindows.first(where: { $0.id == id }) else { return }
        DockitLogger.shared.logWindowUndocked(try? window.axWindow.title(), reason: reason)
        if let observer = window.observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        dockedWindows.removeAll { $0.id == id }
    }
    
    func undockAllWindows() {
        dockedWindows.forEach { window in
            try? window.axWindow.setPosition(window.originalFrame.origin)
            // try? window.axWindow.setSize(window.originalFrame.size)
        }
        dockedWindows.removeAll()
    }
    
    private func setupEventMonitor() {
        eventMonitor.onMouseMoved = { [weak self] point in
            self?.handleMouseMovement(point)
        }
        eventMonitor.startMonitoring()
    }
    
    func handleMouseMovement(_ point: NSPoint) {
        dockedWindows.forEach { dockedWindow in
            let isWindowVisible = isWindowVisibleOnScreen(dockedWindow.axWindow)
            
            if respectSpaces && !isWindowVisible {
                return
            }
            
            let shouldShow = dockedWindow.isVisible 
                ? dockedWindow.windowArea.contains(point)
                : dockedWindow.triggerArea.contains(point)
                
            if shouldShow != dockedWindow.isVisible {
                var updatedWindow = dockedWindow
                updatedWindow.isVisible = shouldShow
                
                if shouldShow {
                    DockitLogger.shared.logWindowShown(try? dockedWindow.axWindow.title())
                } else {
                    DockitLogger.shared.logWindowHidden(try? dockedWindow.axWindow.title())
                }
                
                if let index = dockedWindows.firstIndex(where: { $0.id == dockedWindow.id }) {
                    dockedWindows[index] = updatedWindow
                }
                
                if shouldShow {
                    if let window = Windows.shared.inner.first(where: { $0.axWindow == dockedWindow.axWindow }) {
                        window.focus()
                    }
                    
                    if let currentFrame = try? dockedWindow.axWindow.frame(),
                       let screen = NSScreen.main {
                        var newOrigin = currentFrame.origin
                        switch dockedWindow.edge {
                        case .left:
                            newOrigin.x = 0
                        case .right:
                            newOrigin.x = screen.frame.width - currentFrame.width
                        }
                        try? dockedWindow.axWindow.setPosition(newOrigin)
                    }
                } else {
                    dockedWindow.axWindow.dockTo(dockedWindow.edge, exposedPixels: exposedPixels)
                }
            }
        }
    }
    
    private func isWindowVisibleOnScreen(_ window: AxWindow) -> Bool {
        guard let frame = try? window.frame() else { return false }
        
        let screens = NSScreen.screens
        
        for screen in screens {
            if screen.frame.intersects(frame) {
                if let windowId = try? window.cgWindowId(),
                   let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[CFString: Any]] {
                    return windowList.contains { dict in
                        if let id = dict[kCGWindowNumber] as? CGWindowID {
                            return id == windowId
                        }
                        return false
                    }
                }
            }
        }
        
        return false
    }
    
    func dockActiveWindow(to edge: DockEdge) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let axApp = AxApplication(element: AXUIElementCreateApplication(app.processIdentifier))
        guard let window = try? axApp.focusedWindow() else { return }
        
        dockWindow(window, to: edge)
    }
} 
