import SwiftUI

/// A capsule that selects one of a few filters.
public struct FilterChip: View {
    private let title: Text
    private let isSelected: Bool
    private let action: () -> Void

    public init(_ title: Text, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            title
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.fill), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
