import Foundation
import Defaults
import SwiftUI

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @Published private(set) var exposedPixels: Double
    @Published private(set) var triggerAreaWidth: Double
    @Published private(set) var isEnabled: Bool
    @Published private(set) var respectSpaces: Bool
    @Published private(set) var fps: Int
    @Published private(set) var notchStyle: String
    @Published private(set) var showPreview: Bool
    
    // 事件回调
    var onExposedPixelsChanged: ((Double) -> Void)?
    var onTriggerAreaWidthChanged: ((Double) -> Void)?
    var onIsEnabledChanged: ((Bool) -> Void)?
    var onRespectSpacesChanged: ((Bool) -> Void)?
    var onFpsChanged: ((Int) -> Void)?
    var onNotchStyleChanged: ((String) -> Void)?
    var onShowPreviewChanged: ((Bool) -> Void)?
    
    private init() {
        self.exposedPixels = Double(Defaults[.exposedPixels])
        self.triggerAreaWidth = Double(Defaults[.triggerAreaWidth])
        self.isEnabled = Defaults[.isEnabled]
        self.respectSpaces = Defaults[.respectSpaces]
        self.fps = Defaults[.fps]
        self.notchStyle = Defaults[.notchStyle]
        self.showPreview = Defaults[.showPreview]
        
        DockitLogger.shared.logInfo("PreferencesManager 初始化 - 露出像素: \(exposedPixels)px, 触发区域宽度: \(triggerAreaWidth)px")
    }
    
    func updateExposedPixels(_ value: Double) {
        exposedPixels = value
        Defaults[.exposedPixels] = Int(value)
        onExposedPixelsChanged?(value)
    }
    
    func updateTriggerAreaWidth(_ value: Double) {
        triggerAreaWidth = value
        Defaults[.triggerAreaWidth] = Int(value)
        onTriggerAreaWidthChanged?(value)
    }
    
    func updateIsEnabled(_ value: Bool) {
        isEnabled = value
        Defaults[.isEnabled] = value
        onIsEnabledChanged?(value)
    }
    
    func updateRespectSpaces(_ value: Bool) {
        respectSpaces = value
        Defaults[.respectSpaces] = value
        onRespectSpacesChanged?(value)
    }
    
    func updateFps(_ value: Int) {
        fps = value
        Defaults[.fps] = value
        onFpsChanged?(value)
    }
    
    func updateNotchStyle(_ value: String) {
        notchStyle = value
        Defaults[.notchStyle] = value
        onNotchStyleChanged?(value)
    }
    
    func updateShowPreview(_ value: Bool) {
        showPreview = value
        Defaults[.showPreview] = value
        onShowPreviewChanged?(value)
    }
} 
