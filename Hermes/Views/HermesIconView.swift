import SwiftUI

/// Hermes app icon - winged helmet inspired design
struct HermesIconView: View {
    var size: CGFloat = 32
    var isRecording: Bool = false
    
    var body: some View {
        ZStack {
            // Base circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: isRecording 
                            ? [Color(hex: "FF3B30"), Color(hex: "FF6B6B")]
                            : [Color(hex: "FFB347"), Color(hex: "FF6B35")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Wing icon (represents Hermes' winged helmet)
            Image(systemName: "wing")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(.white)
                .offset(x: -size * 0.02, y: size * 0.02)
            
            // Recording indicator dot
            if isRecording {
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .offset(x: size * 0.28, y: -size * 0.28)
                    .modifier(PulseEffect())
            }
        }
    }
}

/// Alternative icon using available SF Symbols
struct HermesMenuBarIcon: View {
    var isRecording: Bool = false
    
    var body: some View {
        Image(systemName: isRecording ? "burst.fill" : "bolt.horizontal.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isRecording ? .red : .orange)
    }
}

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 0.9)
            .opacity(isPulsing ? 1 : 0.7)
            .animation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        HermesIconView(size: 64, isRecording: false)
        HermesIconView(size: 64, isRecording: true)
        HermesIconView(size: 128, isRecording: false)
    }
    .padding()
}






