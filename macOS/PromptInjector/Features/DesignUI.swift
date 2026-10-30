import AppKit

enum DesignAssets {
    private static var cache: [String: NSImage] = [:]
    static func image(_ name: String, template: Bool = true) -> NSImage? {
        if cache[name] == nil {
            // AppKit's SVG renderer omits Figma blur filters; PNG exports preserve the authored glow.
            let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Design")
                ?? Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Design")
                ?? Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Design")
                ?? Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "Design")
            if let url, let image = NSImage(contentsOf: url) {
                if url.pathExtension == "png", name == "Logo" || name.hasPrefix("Dot-") {
                    if let pixels = image.representations.first {
                        image.size = NSSize(width: CGFloat(pixels.pixelsWide) / 3, height: CGFloat(pixels.pixelsHigh) / 3)
                    }
                }
                cache[name] = image
            }
        }
        guard let copy = cache[name]?.copy() as? NSImage else { return nil }
        copy.isTemplate = template
        return copy
    }
}

class FlippedView: NSView { override var isFlipped: Bool { true } }

class SurfaceView: FlippedView {
    init(color: NSColor = Theme.panel, radius: CGFloat = 16, border: NSColor? = Theme.border) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        layer?.cornerRadius = radius
        layer?.borderWidth = border == nil ? 0 : 1
        layer?.borderColor = border?.cgColor
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class LogoView: FlippedView {
    private let image = NSImageView()
    override var wantsDefaultClipping: Bool { false }
    override init(frame: NSRect) {
        super.init(frame: frame)
        image.image = DesignAssets.image("Logo", template: false)
        image.imageScaling = .scaleProportionallyUpOrDown
        addSubview(image)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        let scale = bounds.width / 32
        // Figma's raster render bounds relative to the logical 32pt slot, including its halo.
        image.frame = NSRect(x: 0, y: -5.261 * scale, width: (112 / 3.0) * scale, height: (124 / 3.0) * scale)
    }
}

final class CategoryDot: FlippedView {
    private let image = NSImageView()
    override var wantsDefaultClipping: Bool { false }
    init(category: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 7, height: 7))
        image.image = DesignAssets.image("Dot-" + category, template: false)
        image.imageScaling = .scaleNone
        addSubview(image)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() { super.layout(); image.frame = NSRect(x: -10, y: -10, width: 27, height: 27) }
}

final class ChoiceSegments: SurfaceView {
    var onSelect: ((Int) -> Void)?
    var selectedIndex = 0 { didSet { update() } }
    private(set) var buttons: [ActionButton] = []
    init(_ labels: [String]) {
        super.init(color: Theme.band, radius: 10, border: nil)
        for (i, label) in labels.enumerated() {
            let button = ActionButton(title: label, symbol: nil, target: nil, action: nil)
            button.font = .systemFont(ofSize: 12)
            button.onPress = { [weak self] in self?.selectedIndex = i; self?.onSelect?(i) }
            addSubview(button); buttons.append(button)
        }
        update()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func update() {
        for (i, button) in buttons.enumerated() {
            button.selectedStyle = i == selectedIndex
            button.ink = i == selectedIndex ? Theme.text : Theme.secondary
            button.setAccessibilityValue(i == selectedIndex ? 1 : 0)
        }
    }
    override func layout() {
        super.layout()
        let w = (bounds.width - 8 - CGFloat(max(0, buttons.count - 1)) * 4) / CGFloat(max(1, buttons.count))
        for (i, button) in buttons.enumerated() {
            button.frame = NSRect(x: 4 + CGFloat(i) * (w + 4), y: 4, width: w, height: bounds.height - 8)
            button.layer?.cornerRadius = 7
        }
    }
}

final class TextDocument: FlippedView {
    let text = NSTextView()
    init() {
        super.init(frame: .zero)
        text.isEditable = false; text.isSelectable = true; text.drawsBackground = false
        text.textContainerInset = .zero; text.textContainer?.lineFragmentPadding = 0
        text.textContainer?.widthTracksTextView = true; text.focusRingType = .none
        text.isHorizontallyResizable = false
        addSubview(text)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func set(_ value: NSAttributedString, width: CGFloat) { text.textStorage?.setAttributedString(value); arrange(width: width) }
    func arrange(width: CGFloat) {
        let width = max(40, width)
        text.frame = NSRect(x: 0, y: 0, width: width, height: 20)
        text.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        if let container = text.textContainer { text.layoutManager?.ensureLayout(for: container) }
        let h = ceil(text.layoutManager?.usedRect(for: text.textContainer!).height ?? 20) + 4
        text.frame.size.height = h; setFrameSize(NSSize(width: width, height: h))
    }
}

extension Theme {
    static func hex(_ value: UInt32) -> NSColor { NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1) }
    static let canvas = hex(0x0B0B0B), shell = hex(0x101010), panel = hex(0x151515)
    static let band = hex(0x1D1D1D), selection = hex(0x292929), border = hex(0x2B2B2B)
    static func categoryColor(_ id: String) -> NSColor {
        hex(["requirements": 0xF5D975, "coding": 0x99A8FF, "debugging": 0xFFAA85, "review": 0xC5A0FF, "release": 0xF699C8][id] ?? 0xF4F4F2)
    }
    static func categoryName(_ id: String) -> String { PromptCategory.all.first { $0.id == id }?.name ?? id }
    static func glow(_ label: NSTextField, color: NSColor) {
        label.textColor = color; label.wantsLayer = true
        let shadow = NSShadow(); shadow.shadowColor = color.withAlphaComponent(0.55); shadow.shadowBlurRadius = 3; shadow.shadowOffset = .zero
        label.attributedStringValue = NSAttributedString(string: label.stringValue, attributes: [.font: label.font ?? NSFont.systemFont(ofSize: 14), .foregroundColor: color, .shadow: shadow])
        label.layer?.shadowColor = color.cgColor; label.layer?.shadowOpacity = 0.28; label.layer?.shadowRadius = 9; label.layer?.shadowOffset = .zero
    }
    static func body(_ value: String, size: CGFloat = 13, color: NSColor = Theme.text, lineHeight: CGFloat = 22, weight: NSFont.Weight = .regular) -> NSAttributedString {
        let p = NSMutableParagraphStyle(); p.minimumLineHeight = lineHeight; p.maximumLineHeight = lineHeight; p.lineBreakMode = .byCharWrapping
        return NSAttributedString(string: value, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p])
    }
}
