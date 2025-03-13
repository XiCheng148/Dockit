import SwiftUI

struct StatusIndicator: View {
    let isEnabled: Bool
    
    var body: some View {
        Circle()
            .fill(isEnabled ? Color.green : Color.red)
            .frame(width: 8, height: 8)
    }
} 
