import AppKit

// Plain AppKit entry point. The menu-bar item, popover, and Settings window are
// managed by StatusItemController; no SwiftUI App/Scene (which would open a
// stray window for an app with no regular windows).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
