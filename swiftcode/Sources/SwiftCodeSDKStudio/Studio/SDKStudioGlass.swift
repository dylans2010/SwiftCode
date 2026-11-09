import AppKit
import SwiftUI






public enum SDKStudioGlassStyle: Sendable {
    case subtle
    case standard
    case prominent
}

public extension View {
    
    func sdkStudioGlass(
        style: SDKStudioGlassStyle = .standard,
        cornerRadius: CGFloat = 12,
        tint: Color? = nil,
        borderWidth: CGFloat = 1
    ) -> some View {
        modifier(
            SDKStudioGlassModifier(
                style: style,
                cornerRadius: cornerRadius,
                tint: tint,
                borderWidth: borderWidth
            )
        )
    }
}

private struct SDKStudioGlassModifier: ViewModifier {
    let style: SDKStudioGlassStyle
    let cornerRadius: CGFloat
    let tint: Color?
    let borderWidth: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                shape.fill(.regularMaterial)
            }
            .overlay {
                if let tint {
                    shape.fill(tint.opacity(opacity(for: style)))
                }
            }
            .overlay {
                shape.strokeBorder(
                    Color.primary.opacity(borderOpacity(for: style)),
                    lineWidth: borderWidth
                )
            }
    }

    private func opacity(for style: SDKStudioGlassStyle) -> Double {
        switch style {
        case .subtle: return 0.04
        case .standard: return 0.08
        case .prominent: return 0.14
        }
    }

    private func borderOpacity(for style: SDKStudioGlassStyle) -> Double {
        switch style {
        case .subtle: return 0.08
        case .standard: return 0.14
        case .prominent: return 0.22
        }
    }
}
