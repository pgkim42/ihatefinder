import AppKit

/// Warm-ink chrome. Deliberately not a system toolbar, source list, or accent-blue selection.
enum Studio {
    static let accent = NSColor(srgbRed: 1, green: 0.361, blue: 0.224, alpha: 1)

    static let canvas = dynamic(light: (0.953, 0.937, 0.906), dark: (0.078, 0.071, 0.063))
    static let rail = dynamic(light: (0.918, 0.894, 0.855), dark: (0.102, 0.094, 0.086))
    static let card = dynamic(light: (1, 0.992, 0.976), dark: (0.133, 0.122, 0.110))
    static let chip = dynamic(light: (0.898, 0.871, 0.827), dark: (0.188, 0.173, 0.157))
    static let well = dynamic(light: (0.933, 0.910, 0.875), dark: (0.176, 0.161, 0.145))
    static let ink = dynamic(light: (0.110, 0.098, 0.090), dark: (0.957, 0.937, 0.902))
    static let muted = dynamic(light: (0.478, 0.447, 0.416), dark: (0.659, 0.624, 0.588))
    static let hairline = dynamic(light: (0.847, 0.816, 0.769), dark: (0.247, 0.224, 0.200))
    static let selection = dynamic(
        light: (1, 0.361, 0.224, 0.22),
        dark: (1, 0.361, 0.224, 0.36)
    )


    static let nameFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    static let metaFont = NSFont.systemFont(ofSize: 12, weight: .regular)
    static let pathFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    static let headerFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
    static let sectionFont = NSFont.systemFont(ofSize: 10, weight: .bold)

    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            let components = isDark(appearance) ? dark : light
            return NSColor(srgbRed: components.0, green: components.1, blue: components.2, alpha: components.3)
        })
    }

    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> NSColor {
        dynamic(light: (light.0, light.1, light.2, 1), dark: (dark.0, dark.1, dark.2, 1))
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

final class StudioCanvas: NSView {
    var fill: NSColor = Studio.canvas
    var cornerRadius: CGFloat = 0
    var onAppearanceChange: (() -> Void)?

    override var isOpaque: Bool { cornerRadius == 0 }

    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        if cornerRadius > 0 {
            NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        } else {
            dirtyRect.fill()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
        needsDisplay = true
    }
}

final class StudioMark: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: 4, height: 16) }

    override func draw(_ dirtyRect: NSRect) {
        Studio.accent.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2).fill()
    }
}

final class StudioHairline: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 1) }

    override func draw(_ dirtyRect: NSRect) {
        Studio.hairline.setFill()
        bounds.fill()
    }
}

final class StudioDot: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: 7, height: 7) }

    override func draw(_ dirtyRect: NSRect) {
        Studio.accent.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}

/// Borderless symbol button. The title is the accessibility label and tooltip, not drawn text.
final class StudioIconButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        focusRingType = .none
        wantsLayer = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    convenience init(title: String, symbol: String, action: Selector) {
        self.init(frame: .zero)
        self.title = ""
        toolTip = title
        setAccessibilityLabel(title)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        self.action = action
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            Studio.selection.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8).fill()
        }
        guard let image else { return }
        let side: CGFloat = 15
        let dest = NSRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        let tinted = NSImage(size: dest.size, flipped: false) { rect in
            (self.isEnabled ? Studio.ink : Studio.muted).setFill()
            rect.fill()
            image.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        tinted.draw(in: dest, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

final class StudioTextButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        focusRingType = .none
        font = .systemFont(ofSize: 12, weight: .semibold)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func draw(_ dirtyRect: NSRect) {
        let fill = isHighlighted ? Studio.selection : Studio.chip
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        let text = NSAttributedString(string: title, attributes: [
            .font: font as Any,
            .foregroundColor: Studio.ink,
        ])
        let size = text.size()
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }
}

final class StudioTextFieldCell: NSTextFieldCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        Studio.well.setFill()
        NSBezierPath(roundedRect: cellFrame, xRadius: 10, yRadius: 10).fill()
        super.drawInterior(withFrame: cellFrame.insetBy(dx: 12, dy: 6), in: controlView)
    }

    override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        super.edit(withFrame: rect.insetBy(dx: 12, dy: 4), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        super.select(
            withFrame: rect.insetBy(dx: 12, dy: 4),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: selStart,
            length: selLength
        )
    }
}



final class StudioHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        Studio.card.setFill()
        cellFrame.fill()
        let title = NSAttributedString(string: stringValue, attributes: [
            .font: Studio.headerFont,
            .foregroundColor: Studio.muted,
        ])
        let size = title.size()
        title.draw(at: NSPoint(x: cellFrame.minX + 10, y: cellFrame.midY - size.height / 2))
    }

    override func drawSortIndicator(
        withFrame cellFrame: NSRect,
        in controlView: NSView,
        ascending: Bool,
        priority: Int
    ) {
        guard priority == 0 else { return }
        let x = cellFrame.maxX - 16
        let y = cellFrame.midY
        let path = NSBezierPath()
        if ascending {
            path.move(to: NSPoint(x: x, y: y - 3))
            path.line(to: NSPoint(x: x + 4, y: y + 3))
            path.line(to: NSPoint(x: x + 8, y: y - 3))
        } else {
            path.move(to: NSPoint(x: x, y: y + 3))
            path.line(to: NSPoint(x: x + 4, y: y - 3))
            path.line(to: NSPoint(x: x + 8, y: y + 3))
        }
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        Studio.accent.setStroke()
        path.stroke()
    }
}

final class StudioRowView: NSTableRowView {
    var surface: NSColor = Studio.card
    var horizontalInset: CGFloat = 8

    override var isSelected: Bool {
        didSet { needsDisplay = true }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        surface.setFill()
        bounds.fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {}

    override func draw(_ dirtyRect: NSRect) {
        drawBackground(in: dirtyRect)
        guard isSelected else { return }
        let inset = bounds.insetBy(dx: horizontalInset, dy: 3)
        Studio.selection.setFill()
        NSBezierPath(roundedRect: inset, xRadius: 8, yRadius: 8).fill()
        let bar = NSRect(x: inset.minX, y: inset.minY + 4, width: 3, height: max(4, inset.height - 8))
        Studio.accent.setFill()
        NSBezierPath(roundedRect: bar, xRadius: 1.5, yRadius: 1.5).fill()
    }
}

enum StudioField {
    static func stylePath(_ field: NSTextField, placeholder: String) {
        let cell = StudioTextFieldCell(textCell: "")
        cell.isEditable = true
        cell.isSelectable = true
        cell.isBordered = false
        cell.isBezeled = false
        cell.drawsBackground = false
        cell.font = Studio.pathFont
        cell.lineBreakMode = .byTruncatingMiddle
        cell.usesSingleLineMode = true
        cell.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .font: Studio.pathFont,
            .foregroundColor: Studio.muted,
        ])
        field.cell = cell
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = Studio.pathFont
        field.textColor = Studio.ink
        field.placeholderString = placeholder
    }

    static func styleSearch(_ field: NSSearchField, placeholder: String) {
        field.focusRingType = .none
        field.font = Studio.metaFont
        field.textColor = Studio.ink
        field.placeholderString = placeholder
        field.sendsSearchStringImmediately = true
    }
}
