import Cocoa
import SwiftUI

class ViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // The view controller doesn't need much setup as our app is menu bar based
        // This view controller is mainly used for hosting SwiftUI views like preferences or welcome screens
    }
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 530))
    }
    
    // Helper method to present a SwiftUI view in this controller
    func presentSwiftUIView<T: View>(_ swiftUIView: T, title: String? = nil) {
        let hostingController = NSHostingController(rootView: swiftUIView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add as child view controller
        addChild(hostingController)
        
        // Add the SwiftUI view to our view
        self.view.addSubview(hostingController.view)
        
        // Set constraints to fill our view
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        // Update window title if provided
        if let title = title, let window = self.view.window {
            window.title = title
        }
    }
} 