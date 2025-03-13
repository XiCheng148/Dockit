import Foundation

public class Dockit {
    public static let shared = Dockit()
    
    private let manager = DockitManager.shared
    
    private init() {}
    
    public func start() {
        DockitShortcuts.register()
    }
    
    public func stop() {
        manager.undockAllWindows()
    }
} 
