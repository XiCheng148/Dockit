import SwiftUI
import AppKit

struct ModifierKeysSelector: View {
    let title: String
    @Binding var selection: UInt
    
    private let modifierOptions: [(String, NSEvent.ModifierFlags)] = [
        ("无", []),
        ("⌘ Command", .command),
        ("⌥ Option", .option),
        ("⌃ Control", .control),
        ("⇧ Shift", .shift),
    ]
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(modifierOptions, id: \.0) { option in
                    Text(option.0)
                        .tag(option.1.rawValue)
                }
            }
            .frame(width: 150)
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    ModifierKeysSelector(title: "测试选择器", selection: .constant(0))
} 
