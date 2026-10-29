import AppKit

enum Theme {
    static let radius: CGFloat = 26
    static let text = NSColor(calibratedWhite: 0.94, alpha: 1)
    static let secondary = NSColor(calibratedWhite: 0.66, alpha: 1)
    static let tertiary = NSColor(calibratedWhite: 0.58, alpha: 1)
    static let accent = NSColor(calibratedWhite: 0.76, alpha: 1)
    static let error = NSColor(calibratedRed: 1, green: 0.68, blue: 0.62, alpha: 1)
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
    var primary = false
    private var hovered = false
    private var tracking: NSTrackingArea?
    convenience init(title: String, symbol: String? = nil, primary: Bool = false, target: AnyObject?, action: Selector) {
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
            image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            imagePosition = title.isEmpty ? .imageOnly : .imageLeading
            symbolConfiguration = .init(pointSize: 13, weight: .medium)
        }
        wantsLayer = true
        layer?.cornerRadius = 8
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
        contentTintColor = primary ? NSColor(calibratedWhite: 0.12, alpha: 1) : Theme.text
        if !isEnabled { contentTintColor = Theme.tertiary }
        let fill: NSColor = primary && isEnabled
            ? NSColor(calibratedWhite: isHighlighted ? 0.68 : hovered ? 1 : 0.89, alpha: 1)
            : NSColor(white: 1, alpha: isHighlighted ? 0.14 : hovered ? 0.10 : title.isEmpty ? 0 : 0.055)
        layer?.backgroundColor = fill.cgColor
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
        tint.layer?.backgroundColor = NSColor(calibratedRed: 0.113, green: 0.109, blue: 0.108, alpha: reduceTransparency ? 1 : 0.78).cgColor
        outline.layer?.borderColor = NSColor(white: 1, alpha: increaseContrast ? 0.45 : 0.22).cgColor
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
