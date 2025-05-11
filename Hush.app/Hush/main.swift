// Main entry point for the Hush app.
// This file just creates the application delegate and runs the app.

import Cocoa

// Set up an exception handler to catch startup errors
NSSetUncaughtExceptionHandler { exception in
    let alert = NSAlert()
    alert.messageText = "Hush encountered an error"
    alert.informativeText = "Error details: \(exception.name.rawValue) - \(exception.reason ?? "Unknown error")"
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

// Get the shared application instance
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate

// The AppDelegate will be loaded by AppDelegate+MainMenu.m
// and set via Interface Builder

// Run the application
app.run() 
