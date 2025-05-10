// Main entry point for the Hush app.
// This file just creates the application delegate and runs the app.

import Cocoa

// Get the shared application instance
let app = NSApplication.shared
app.delegate = AppDelegate()

// The AppDelegate will be loaded by AppDelegate+MainMenu.m
// and set via Interface Builder

// Run the application
app.run() 
