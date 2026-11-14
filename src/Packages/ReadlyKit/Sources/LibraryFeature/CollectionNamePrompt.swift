import SwiftUI

/// Asks for the name of a new or renamed collection.
public struct CollectionNamePrompt: ViewModifier {
    private let title: String
    @Binding private var isPresented: Bool
    private let initialName: String
    private let onCommit: (String) -> Void
    @State private var name = ""

    public init(title: String, isPresented: Binding<Bool>, initialName: String = "", onCommit: @escaping (String) -> Void) {
        self.title = title
        _isPresented = isPresented
        self.initialName = initialName
        self.onCommit = onCommit
    }

    public func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                TextField("Name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Save") { onCommit(name) }
            }
            .onChange(of: isPresented) { _, isShown in
                if isShown { name = initialName }
            }
    }
}
