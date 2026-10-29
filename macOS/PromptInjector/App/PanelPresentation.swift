import AppKit

/// A short settle-in / retract animation. Never changes saved geometry or the resting material opacity.
@MainActor final class PanelPresentation {
    private(set) var isPresented = false
    private var generation = 0
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    func show(_ window: NSWindow, animated: Bool = true, completion: (() -> Void)? = nil) {
        generation += 1
        let current = generation
        isPresented = true
        let animate = animated && !reduceMotion()
        let wasVisible = window.isVisible
        let layer = window.contentView?.layer
        let previous = layer?.presentation()?.transform
        layer?.removeAnimation(forKey: "panel-presentation")
        window.ignoresMouseEvents = false
        if !wasVisible { window.alphaValue = animate ? 0 : 1 }
        window.makeKeyAndOrderFront(nil)
        guard animate else { window.alphaValue = 1; completion?(); return }
        animateScale(layer, from: previous ?? scale(0.975, layer: layer), to: CATransform3DIdentity, duration: 0.18)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            window.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            guard let self, self.generation == current, self.isPresented else { return }
            completion?()
        })
    }

    func hide(_ window: NSWindow, animated: Bool = true) {
        generation += 1
        let current = generation
        isPresented = false
        let layer = window.contentView?.layer
        let previous = layer?.presentation()?.transform ?? CATransform3DIdentity
        layer?.removeAnimation(forKey: "panel-presentation")
        let finish = { [weak self, weak window] in
            guard let self, let window, self.generation == current, !self.isPresented else { return }
            window.orderOut(nil)
            window.alphaValue = 1
            window.ignoresMouseEvents = false
            layer?.removeAnimation(forKey: "panel-presentation")
        }
        guard animated, !reduceMotion(), window.isVisible else { finish(); return }
        window.ignoresMouseEvents = true
        animateScale(layer, from: previous, to: scale(0.985, layer: layer), duration: 0.12)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: finish)
    }

    private func scale(_ value: CGFloat, layer: CALayer?) -> CATransform3D {
        var result = CATransform3DMakeScale(value, value, 1)
        if let layer {
            result.m41 = layer.bounds.width * (0.5 - layer.anchorPoint.x) * (1 - value)
            result.m42 = layer.bounds.height * (0.5 - layer.anchorPoint.y) * (1 - value)
        }
        return result
    }
    private func animateScale(_ layer: CALayer?, from: CATransform3D, to: CATransform3D, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = NSValue(caTransform3D: from)
        animation.toValue = NSValue(caTransform3D: to)
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
        layer?.add(animation, forKey: "panel-presentation")
    }
}
