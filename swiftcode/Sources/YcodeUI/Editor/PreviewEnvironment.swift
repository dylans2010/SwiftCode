import SwiftUI

@MainActor
public struct PreviewEnvironmentModifier: ViewModifier {
    let state: PreviewState

    public func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, state.isDarkMode ? .dark : .light)
            .environment(\.dynamicTypeSize, state.dynamicTypeSize)
            .environment(\.locale, Locale(identifier: state.localization))
            .environment(\.layoutDirection, state.layoutDirection)
            .environment(\.displayScale, state.displayScale)
            .environment(\.legibilityWeight, state.isBoldTextEnabled ? .bold : .regular)
            .frame(width: state.customWidth.map { CGFloat($0) }, height: state.customHeight.map { CGFloat($0) })
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: state.safeAreaInsets.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: state.safeAreaInsets.bottom) }
    }
}

public extension View {
    @MainActor
    func applyPreviewEnvironment(_ state: PreviewState) -> some View {
        self.modifier(PreviewEnvironmentModifier(state: state))
    }
}
