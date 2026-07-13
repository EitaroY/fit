import ServiceManagement

/// Launch-at-login via SMAppService (macOS 13+). Most reliable when the app
/// runs from /Applications rather than a DerivedData build folder.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
