import ImageIO
import SwiftUI

/// Shows encoded image data, or a neutral placeholder with the book title.
public struct CoverImage: View {
    private let data: Data?
    private let title: String
    @State private var image: CGImage?

    public init(data: Data?, title: String) {
        self.data = data
        self.title = title
    }

    public var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .task(id: data) { image = data.flatMap(Self.decode) }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 10) {
                Image(systemName: "book.closed")
                    .font(.title)
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }

    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
