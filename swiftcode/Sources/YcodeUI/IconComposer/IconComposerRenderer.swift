import AppKit
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import YcodeIcon

public enum IconComposerMask: Sendable {
    case none
    case squircle
    case circle
}

public enum IconComposerRenderer {
    public static let rotationKey = "rotation-degrees"
    public static let blurKey = "blur-radius"

    public static func cgColor(_ c: IconColor) -> CGColor {
        let (r, g, b, a) = c.rgba
        return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, a].map { CGFloat($0) })!
    }

    public static func loadLayerImage(package: IconPackage, name: String) -> CGImage? {
        guard !name.isEmpty else { return nil }
        let url = package.assetURL(name)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    public static func render(package: IconPackage, appearance: IconAppearance, platform: IconPlatform, pixels: Int) -> CGImage? {
        render(document: package.document, package: package, appearance: appearance, platform: platform, pixels: pixels, mask: .none)
    }

    public static func render(document: IconDocument, package: IconPackage?, appearance: IconAppearance, platform: IconPlatform,
                              pixels: Int, mask: IconComposerMask = .none) -> CGImage? {
        guard pixels > 0 else { return nil }
        let resolved = document.resolved(appearance, platform)
        let canvas = resolved.canvasSize
        let k = Double(pixels) / canvas
        guard let ctx = makeContext(pixels, pixels) else { return nil }
        drawBackground(IconBackground(resolved.background, appearance: resolved.appearance), in: ctx, pixels: pixels)
        let bottomFirst = resolved.groups.enumerated().filter { !$0.element.hidden }.reversed()
        for (gi, g) in bottomFirst {
            guard document.groups.indices.contains(gi) else { continue }
            let rawGroup = document.groups[gi]
            guard let groupImage = renderGroup(raw: rawGroup, resolved: g, package: package, canvas: canvas, k: k,
                                               appearance: resolved.appearance) else { continue }
            drawGroup(groupImage, resolved: g, in: ctx, canvas: canvas, k: k)
        }
        guard let image = ctx.makeImage() else { return nil }
        if mask != .none { return applyMask(mask, to: image) }
        return image
    }

    static func makeContext(_ w: Int, _ h: Int) -> CGContext? {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    static func drawBackground(_ bg: IconBackground, in ctx: CGContext, pixels: Int) {
        let p = CGFloat(pixels)
        if bg.stops.count <= 1 {
            let c = bg.stops.first?.color ?? IconColor(space: .extendedGray, components: [1, 1])
            ctx.setFillColor(IconComposerRenderer.cgColor(c))
            ctx.fill(CGRect(x: 0, y: 0, width: p, height: p))
            return
        }
        let colors = bg.stops.map { IconComposerRenderer.cgColor($0.color) } as CFArray
        let locations = bg.stops.map { CGFloat($0.location) } as [CGFloat]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else {
            ctx.setFillColor(IconComposerRenderer.cgColor(bg.stops[0].color))
            ctx.fill(CGRect(x: 0, y: 0, width: p, height: p))
            return
        }
        let start = unitPoint(bg.orientation.start, pixels: pixels)
        let end = unitPoint(bg.orientation.stop, pixels: pixels)
        ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
    }

    static func unitPoint(_ p: IconPoint, pixels: Int) -> CGPoint {
        CGPoint(x: CGFloat(p.x) * CGFloat(pixels), y: CGFloat(1 - p.y) * CGFloat(pixels))
    }

    static func renderGroup(raw: IconGroup, resolved: ResolvedGroup, package: IconPackage?, canvas: Double, k: Double,
                            appearance: IconAppearance) -> CGImage? {
        let side = Int((canvas * k).rounded())
        guard side > 0, let ctx = makeContext(side, side) else { return nil }
        let resolvedLayers = resolved.layers
        for (li, rl) in resolvedLayers.enumerated().reversed() {
            guard rl.hidden == false else { continue }
            let rawLayer = raw.layers.indices.contains(li) ? raw.layers[li] : nil
            drawLayer(resolved: rl, raw: rawLayer, package: package, in: ctx, canvas: canvas, k: k, appearance: appearance)
        }
        guard var image = ctx.makeImage() else { return nil }
        let blurRadius = resolved.blurMaterial.effectiveValue
        if blurRadius > 0 {
            image = blurred(image, radius: blurRadius * k * 24) ?? image
        }
        if resolved.refractivity.enabled {
            image = glassified(image, strength: min(max(resolved.refractivity.strength, 0), 1)) ?? image
        }
        return image
    }

    static func drawLayer(resolved rl: ResolvedLayer, raw: IconLayer?, package: IconPackage?, in ctx: CGContext,
                          canvas: Double, k: Double, appearance: IconAppearance) {
        guard let name = rl.imageName, let package,
              let source = loadLayerImage(package: package, name: name) else { return }
        let natural = IconSize(width: Double(source.width), height: Double(source.height))
        let frame = IconGeometry.layerFrame(natural: natural, layer: rl.position, group: .identity, canvas: canvas)
        let w = CGFloat(frame.width * k), h = CGFloat(frame.height * k)
        guard w > 0.5, h > 0.5 else { return }
        let side = CGFloat(ctx.width)
        let blur = raw.flatMap { $0.extra[blurKey]?.numberValue } ?? 0
        let rotation = raw.flatMap { $0.position.value?.extra[rotationKey]?.numberValue } ?? 0
        let needsOffscreen = blur > 0 || rl.glass || !rl.fill.keepsArtworkColors
        var image = source
        if needsOffscreen {
            let iw = Int(w.rounded(.up)), ih = Int(h.rounded(.up))
            if iw > 0, ih > 0, let layerCtx = makeContext(iw, ih) {
                layerCtx.interpolationQuality = .high
                layerCtx.draw(source, in: CGRect(x: 0, y: 0, width: CGFloat(iw), height: CGFloat(ih)))
                if blur > 0 {
                    image = blurred(layerCtx.makeImage() ?? image, radius: blur * k) ?? image
                }
                if !rl.fill.keepsArtworkColors {
                    image = tinted(image, fill: rl.fill, appearance: appearance, size: CGSize(width: CGFloat(iw), height: CGFloat(ih))) ?? image
                }
                if rl.glass, let g = glassified(image, strength: 1) { image = g }
            }
        }
        let cx = CGFloat(frame.x * k) + w / 2
        let cy = side - (CGFloat(frame.y * k) + h / 2)
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        if rotation != 0 { ctx.rotate(by: -CGFloat(rotation) * .pi / 180) }
        ctx.setAlpha(CGFloat(min(max(rl.opacity, 0), 1)))
        ctx.setBlendMode(blendMode(rl.blendMode))
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        ctx.restoreGState()
    }

    static func drawGroup(_ image: CGImage, resolved g: ResolvedGroup, in ctx: CGContext, canvas: Double, k: Double) {
        let pos = g.position
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let height = CGFloat(ctx.height)
        let cx = CGFloat(canvas * k / 2 + pos.translation.x * k)
        let cy = height - CGFloat(canvas * k / 2 + pos.translation.y * k)
        ctx.saveGState()
        let shadow = g.shadow
        if shadow.knownKind != .none, shadow.opacity > 0 {
            ctx.setShadow(offset: CGSize(width: 0, height: CGFloat(-10 * k)), blur: CGFloat(18 * k),
                          color: CGColor(gray: 0, alpha: shadow.opacity * 0.3))
        }
        ctx.translateBy(x: cx, y: cy)
        ctx.scaleBy(x: CGFloat(pos.scale), y: CGFloat(pos.scale))
        ctx.setAlpha(CGFloat(min(max(g.opacity, 0), 1)))
        ctx.setBlendMode(blendMode(g.blendMode))
        ctx.draw(image, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        ctx.restoreGState()
    }

    public static func blendMode(_ m: IconBlendMode) -> CGBlendMode {
        switch m {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .darken: .darken
        case .lighten: .lighten
        case .softLight: .softLight
        case .hardLight: .hardLight
        case .plusDarker: .plusDarker
        case .plusLighter: .plusLighter
        }
    }

    static func blurred(_ image: CGImage, radius: Double) -> CGImage? {
        guard radius > 0.01 else { return image }
        let ci = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return image }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let out = filter.outputImage else { return image }
        let cropped = out.cropped(to: ci.extent)
        return CIContext().createCGImage(cropped, from: cropped.extent)
    }

    static func glassified(_ image: CGImage, strength: Double) -> CGImage? {
        let w = image.width, h = image.height
        guard w > 0, h > 0, let ctx = makeContext(w, h) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        let soft = blurred(ctx.makeImage() ?? image, radius: max(0.6, Double(min(w, h)) * 0.004 * strength)) ?? image
        ctx.clear(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        ctx.draw(soft, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        ctx.setBlendMode(.sourceAtop)
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [CGColor(gray: 1, alpha: 0.34 * strength), CGColor(gray: 1, alpha: 0)] as CFArray,
                                        locations: [0, 1]) else { return ctx.makeImage() }
        ctx.drawLinearGradient(gradient, start: CGPoint(x: CGFloat(w) * 0.2, y: CGFloat(h)), end: CGPoint(x: CGFloat(w) * 0.8, y: CGFloat(h) * 0.45), options: [])
        ctx.setBlendMode(.plusLighter)
        ctx.setAlpha(0.05 * strength)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        return ctx.makeImage()
    }

    static func tinted(_ image: CGImage, fill: IconFill, appearance: IconAppearance, size: CGSize) -> CGImage? {
        let w = Int(size.width.rounded()), h = Int(size.height.rounded())
        guard w > 0, h > 0, let ctx = makeContext(w, h) else { return image }
        let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
        let bg = IconBackground(fill, appearance: appearance)
        drawBackgroundScaled(bg, in: ctx, rect: rect)
        ctx.setBlendMode(.destinationIn)
        ctx.draw(image, in: rect)
        return ctx.makeImage()
    }

    static func drawBackgroundScaled(_ bg: IconBackground, in ctx: CGContext, rect: CGRect) {
        if bg.stops.count <= 1 {
            ctx.setFillColor(IconComposerRenderer.cgColor(bg.stops.first?.color ?? IconColor(space: .extendedGray, components: [1, 1])))
            ctx.fill(rect)
            return
        }
        let colors = bg.stops.map { IconComposerRenderer.cgColor($0.color) } as CFArray
        let locations = bg.stops.map { CGFloat($0.location) } as [CGFloat]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
        let start = CGPoint(x: rect.minX + CGFloat(bg.orientation.start.x) * rect.width,
                            y: rect.maxY - CGFloat(bg.orientation.start.y) * rect.height)
        let end = CGPoint(x: rect.minX + CGFloat(bg.orientation.stop.x) * rect.width,
                          y: rect.maxY - CGFloat(bg.orientation.stop.y) * rect.height)
        ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
    }

    static func applyMask(_ mask: IconComposerMask, to image: CGImage) -> CGImage? {
        let w = image.width, h = image.height
        guard let ctx = makeContext(w, h) else { return image }
        let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
        let path = NSBezierPath()
        switch mask {
        case .none: return image
        case .circle: path.appendOval(in: rect)
        case .squircle:
            let r = CGFloat(min(w, h)) * 0.2237
            path.appendRoundedRect(rect, xRadius: r, yRadius: r)
        }
        ctx.saveGState()
        ctx.addPath(path.cgPath)
        ctx.clip()
        ctx.draw(image, in: rect)
        ctx.restoreGState()
        return ctx.makeImage()
    }

    public static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
