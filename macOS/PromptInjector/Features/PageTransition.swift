import AppKit

/// Animates only the readable viewport. The material, navigation and action bar stay still.
@MainActor final class PageTransition {
    enum Direction { case forward, backward }
    private var outgoing: PassiveView?
    private weak var incoming: NSView?
    private var generation = 0
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var hasSnapshot: Bool { outgoing != nil }

    func prepare(outgoing view: NSView, in host: NSView, animated: Bool) {
        cancel()
        guard animated, !reduceMotion(), view.window?.isVisible == true, !view.isHidden,
              view.bounds.width > 0, view.bounds.height > 0,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds), bitmap.hasAlpha else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let image = bitmap.cgImage else { return }
        let snapshot = PassiveView(frame: view.frame)
        snapshot.wantsLayer = true
        snapshot.layer?.contents = image
        snapshot.layer?.contentsScale = view.window?.backingScaleFactor ?? 2
        snapshot.layer?.contentsGravity = .resize
        snapshot.setAccessibilityElement(false)
        host.addSubview(snapshot)
        outgoing = snapshot
    }

    func play(incoming view: NSView, direction: Direction, animated: Bool) {
        guard animated, !reduceMotion(), view.window?.isVisible == true else { cancel(); return }
        generation += 1
        let current = generation
        let sign: CGFloat = direction == .forward ? 1 : -1
        let duration = direction == .forward ? 0.18 : 0.16
        view.wantsLayer = true
        incoming = view
        view.layer?.add(group(fromX: sign * 16, toX: 0, fromOpacity: 0, toOpacity: 1, duration: duration), forKey: "page-arrival")
        if let outgoing {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            outgoing.layer?.opacity = 0
            CATransaction.commit()
            outgoing.layer?.add(group(fromX: 0, toX: -sign * 10, fromOpacity: 1, toOpacity: 0, duration: 0.12), forKey: "page-departure")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.03) { [weak self] in
            guard let self, self.generation == current else { return }
            self.cancel()
        }
    }

    func cancel() {
        generation += 1
        incoming?.layer?.removeAnimation(forKey: "page-arrival")
        incoming = nil
        outgoing?.removeFromSuperview()
        outgoing = nil
    }

    private func group(fromX: CGFloat, toX: CGFloat, fromOpacity: Float, toOpacity: Float, duration: TimeInterval) -> CAAnimationGroup {
        let translation = CABasicAnimation(keyPath: "transform.translation.x")
        translation.fromValue = fromX; translation.toValue = toX
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = fromOpacity; opacity.toValue = toOpacity
        let group = CAAnimationGroup()
        group.animations = [translation, opacity]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
        return group
    }
}
