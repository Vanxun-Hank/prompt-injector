import AppKit

enum Theme {
    static let radius: CGFloat = 24
    static let text = NSColor(srgbRed: 244/255, green: 244/255, blue: 242/255, alpha: 1)
    static let secondary = NSColor(srgbRed: 168/255, green: 168/255, blue: 164/255, alpha: 1)
    static let tertiary = NSColor(srgbRed: 146/255, green: 146/255, blue: 143/255, alpha: 1)
    static let accent = NSColor(calibratedWhite: 0.76, alpha: 1)
    static let error = hex(0xFFAA9D)
    static func label(_ text: String = "", size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor = Theme.text) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isSelectable = false
        return label
    }
}

final class ActionButton: NSButton {
    var primary = false { didSet { refresh() } }
    var outlined = false { didSet { refresh() } }
    var selectedStyle = false { didSet { refresh() } }
    var ink: NSColor? { didSet { refresh() } }
    var onPress: (() -> Void)? { didSet { if onPress != nil { target = self; action = #selector(press) } } }
    @objc private func press() { onPress?() }
    private var hovered = false
    private var tracking: NSTrackingArea?
    convenience init(title: String, symbol: String? = nil, primary: Bool = false, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.primary = primary
        self.target = target
        self.action = action
        isBordered = false
        bezelStyle = .regularSquare
        font = .systemFont(ofSize: 13, weight: .medium)
        focusRingType = .exterior
        if let symbol {
            let assets = ["doc.on.doc": "Copy", "arrow.up.right": "Insert", "chevron.left": "Back", "xmark": "Close", "plus": "Plus", "pencil": "Edit", "checkmark": "Check", "chart.bar": "Chart", "square.grid.2x2": "Grid"]
            image = assets[symbol].flatMap { DesignAssets.image($0) } ?? NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            imagePosition = title.isEmpty ? .imageOnly : .imageLeading
            symbolConfiguration = .init(pointSize: 13, weight: .medium)
        }
        wantsLayer = true
        layer?.cornerRadius = 10
        setAccessibilityRole(.button)
        refresh()
    }
    override var isEnabled: Bool { didSet { refresh() } }
    override var isHighlighted: Bool { didSet { refresh() } }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; refresh() }
    override func mouseExited(with event: NSEvent) { hovered = false; refresh() }
    private func refresh() {
        contentTintColor = ink ?? Theme.text
        if !isEnabled { contentTintColor = Theme.tertiary }
        let fill: NSColor = (primary || selectedStyle) && isEnabled
            ? (isHighlighted ? Theme.hex(0x353535) : hovered ? Theme.hex(0x323232) : Theme.selection)
            : NSColor(white: 1, alpha: isHighlighted ? 0.12 : hovered ? 0.06 : 0)
        layer?.backgroundColor = fill.cgColor
        layer?.borderWidth = outlined ? 1 : 0
        layer?.borderColor = Theme.border.cgColor
    }
}

final class DragHeader: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        if hit is NSButton { return hit }
        return self
    }
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

class MaterialSurface: NSView {
    let material = NSVisualEffectView()
    let tint = NSView()
    let outline = PassiveView()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = Theme.radius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        material.appearance = NSAppearance(named: .darkAqua)
        material.wantsLayer = true
        addSubview(material)
        tint.wantsLayer = true
        addSubview(tint)
        outline.wantsLayer = true
        outline.layer?.cornerRadius = Theme.radius
        outline.layer?.cornerCurve = .continuous
        outline.layer?.borderWidth = 1
        outline.layer?.borderColor = NSColor(white: 1, alpha: 0.22).cgColor
        updateAccessibilityAppearance()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateAccessibilityAppearance), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc func updateAccessibilityAppearance() {
        applyAccessibilityAppearance(reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                                     increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
    }
    func applyAccessibilityAppearance(reduceTransparency: Bool, increaseContrast: Bool) {
        material.isHidden = reduceTransparency
        tint.layer?.backgroundColor = Theme.shell.cgColor
        outline.layer?.borderColor = (increaseContrast ? Theme.hex(0x727272) : Theme.hex(0x3C3C3C)).cgColor
    }
    override func layout() {
        super.layout()
        material.frame = bounds
        tint.frame = bounds
        outline.frame = bounds.insetBy(dx: 0.5, dy: 0.5)
    }
    func finishOutline() { addSubview(outline) }

    private func edges(at point: NSPoint) -> (left: Bool, right: Bool, bottom: Bool, top: Bool) {
        let corner = (point.x < 22 || point.x > bounds.width - 22) && (point.y < 22 || point.y > bounds.height - 22)
        let margin: CGFloat = corner ? 16 : 5
        return (point.x < margin, point.x > bounds.width - margin, point.y < margin, point.y > bounds.height - margin)
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = convert(point, from: superview)
        let e = edges(at: p)
        if bounds.contains(p), e.left || e.right || e.bottom || e.top { return self }
        return super.hitTest(point)
    }
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let edge = edges(at: convert(event.locationInWindow, from: nil))
        guard edge.left || edge.right || edge.bottom || edge.top else { return }
        let initial = window.frame
        let origin = NSEvent.mouseLocation
        while true {
            guard let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp], until: Date(timeIntervalSinceNow: 0.05), inMode: .eventTracking, dequeue: true) else {
                if NSEvent.pressedMouseButtons & 1 == 0 { break }
                continue
            }
            if next.type == .leftMouseUp { break }
            let mouse = NSEvent.mouseLocation
            let dx = mouse.x - origin.x, dy = mouse.y - origin.y
            var rect = initial
            if edge.right { rect.size.width = max(window.minSize.width, initial.width + dx) }
            if edge.left {
                rect.size.width = max(window.minSize.width, initial.width - dx)
                rect.origin.x = initial.maxX - rect.width
            }
            if edge.top { rect.size.height = max(window.minSize.height, initial.height + dy) }
            if edge.bottom {
                rect.size.height = max(window.minSize.height, initial.height - dy)
                rect.origin.y = initial.maxY - rect.height
            }
            window.setFrame(rect, display: true)
        }
    }
    override func resetCursorRects() {
        addCursorRect(NSRect(x: 0, y: 20, width: 5, height: max(0, bounds.height - 40)), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: bounds.width - 5, y: 20, width: 5, height: max(0, bounds.height - 40)), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: 20, y: 0, width: max(0, bounds.width - 40), height: 5), cursor: .resizeUpDown)
        addCursorRect(NSRect(x: 20, y: bounds.height - 5, width: max(0, bounds.width - 40), height: 5), cursor: .resizeUpDown)
    }
}

/// A decorative view must never intercept text selection, clicks, or window resizing.
final class PassiveView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
