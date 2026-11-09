import AppKit
import CoreGraphics
import Foundation
import YcodeIcon

public enum IconComposerShapes {
    public enum Shape: String, CaseIterable, Sendable {
        case circle
        case roundedSquare = "rounded-square"
        case squircle
        case star
        case diagonalGradient = "diagonal-gradient"
        case ring
    }

    public static func image(_ shape: Shape, pixels: Int) -> CGImage? {
        guard pixels > 0,
              let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let p = CGFloat(pixels)
        ctx.translateBy(x: 0, y: p)
        ctx.scaleBy(x: 1, y: -1)
        let rect = CGRect(x: 0, y: 0, width: p, height: p)
        switch shape {
        case .circle, .squircle, .roundedSquare, .star, .ring:
            drawThemedShape(shape, in: ctx, rect: rect)
        case .diagonalGradient:
            drawDiagonalGradient(in: ctx, rect: rect)
        }
        return ctx.makeImage()
    }

    static func palette() -> (IconColor, IconColor, IconColor) {
        (IconColor.srgb(0.16, 0.45, 0.95),
         IconColor.srgb(0.55, 0.25, 0.95),
         IconColor.srgb(0.10, 0.75, 0.85))
    }

    static func drawThemedShape(_ shape: Shape, in ctx: CGContext, rect: CGRect) {
        let (a, b, _) = palette()
        let path = NSBezierPath()
        let p = rect.width
        switch shape {
        case .circle:
            path.appendOval(in: rect.insetBy(dx: p * 0.08, dy: p * 0.08))
        case .squircle:
            let r = p * 0.2237
            path.appendRoundedRect(rect.insetBy(dx: p * 0.04, dy: p * 0.04), xRadius: r, yRadius: r)
        case .roundedSquare:
            path.appendRoundedRect(rect.insetBy(dx: p * 0.04, dy: p * 0.04), xRadius: p * 0.12, yRadius: p * 0.12)
        case .star:
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let outer = p * 0.42, inner = p * 0.18
            for i in 0..<10 {
                let radius = i % 2 == 0 ? outer : inner
                let angle = -.pi / 2 + CGFloat(i) * .pi / 5
                let pt = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
                if i == 0 { path.move(to: pt) } else { path.line(to: pt) }
            }
            path.close()
        case .ring:
            let outer = rect.insetBy(dx: p * 0.05, dy: p * 0.05)
            path.appendOval(in: outer)
            let innerRect = outer.insetBy(dx: p * 0.16, dy: p * 0.16)
            path.appendOval(in: innerRect)
        case .diagonalGradient:
            drawDiagonalGradient(in: ctx, rect: rect)
            return
        }
        fillShape(path, colors: [a, b], in: ctx, rect: rect)
    }

    static func fillShape(_ path: NSBezierPath, colors: [IconColor], in ctx: CGContext, rect: CGRect) {
        ctx.saveGState()
        ctx.addPath(path.cgPath)
        ctx.clip()
        let cgColors = colors.map { IconComposerRenderer.cgColor($0) } as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.midY),
                                   end: CGPoint(x: rect.maxX, y: rect.midY), options: [])
        }
        ctx.setBlendMode(.sourceAtop)
        ctx.setAlpha(0.22)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        let highlight = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.5)
        ctx.fill(highlight)
        ctx.restoreGState()
    }

    static func drawDiagonalGradient(in ctx: CGContext, rect: CGRect) {
        let (_, b, c) = palette()
        let radius = rect.width * 0.2237
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04),
                                xRadius: radius, yRadius: radius)
        ctx.saveGState()
        ctx.addPath(path.cgPath)
        ctx.clip()
        let colors = [IconComposerRenderer.cgColor(b), IconComposerRenderer.cgColor(c)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.maxY),
                                   end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
        }
        ctx.restoreGState()
    }
}
