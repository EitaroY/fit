import AppKit

// No storyboard/nib: build the application object by hand. LSUIElement in
// the generated Info.plist keeps Fit out of the Dock; .accessory mirrors
// that at runtime.
@main
struct FitApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
