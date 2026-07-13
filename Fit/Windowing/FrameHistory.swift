import CoreGraphics

/// Remembers each window's frame from before its *first* snap so Restore can
/// bring it back. In-memory only; entries are consumed by restore and capped
/// with insertion-order eviction.
struct FrameHistory {
    private var frames: [AXWindowKey: CGRect] = [:]
    private var insertionOrder: [AXWindowKey] = []
    private let capacity: Int

    init(capacity: Int = 64) {
        self.capacity = capacity
    }

    /// Records `frame` as the window's original, unless one is already
    /// stored — repeated snaps must not overwrite the true original.
    mutating func rememberOriginal(_ frame: CGRect, for window: AXWindow) {
        let key = AXWindowKey(window)
        guard frames[key] == nil else { return }
        frames[key] = frame
        insertionOrder.append(key)
        if insertionOrder.count > capacity {
            let evicted = insertionOrder.removeFirst()
            frames.removeValue(forKey: evicted)
        }
    }

    /// Returns and removes the stored original frame, so the next snap
    /// records a fresh one.
    mutating func recallOriginal(for window: AXWindow) -> CGRect? {
        let key = AXWindowKey(window)
        guard let frame = frames.removeValue(forKey: key) else { return nil }
        insertionOrder.removeAll { $0 == key }
        return frame
    }
}
