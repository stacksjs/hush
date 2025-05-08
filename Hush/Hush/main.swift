import Cocoa

// Create an instance of our AppDelegate
let delegate = AppDelegate()

// Get the shared application instance and set its delegate
let app = NSApplication.shared
app.delegate = delegate

// Run the application
app.run() 