import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Renders PDF pages as JPEG images, for covers and pages without text.
enum PDFPageRenderer {
    static func jpeg(of page: PDFPage, maxPixelSize: CGFloat, quality: Double = 0.8) -> Data? {
        let bounds = page.bounds(for: .cropBox)
        let isTurned = page.rotation % 180 != 0
        let size = isTurned ? CGSize(width: bounds.height, height: bounds.width) : bounds.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(4, maxPixelSize / max(size.width, size.height))
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .cropBox, to: context)
        guard let image = context.makeImage() else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
