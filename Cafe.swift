import AppKit
import IOKit.pwr_mgt

@main
@MainActor
final class Cafe: NSObject, NSApplicationDelegate {
  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  var assertion: IOPMAssertionID? {
    didSet { updateIcon() }
  }

  static func main() {
    let application = NSApplication.shared
    let delegate = Cafe()
    application.delegate = delegate
    application.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    if let button = statusItem.button {
      button.target = self
      button.action = #selector(handleClick)
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    updateIcon()
  }

  @objc func handleClick() {
    if NSApp.currentEvent?.type == .rightMouseUp {
      showMenu()
    } else {
      toggle()
    }
  }

  func showMenu() {
    let header = NSMenuItem()
    header.view = headerView()

    let menu = NSMenu()
    menu.addItem(header)
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Quit Cafe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  func headerView() -> NSView {
    let running = assertion != nil
    let dot = NSImageView(image: NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)!)
    dot.symbolConfiguration = .init(pointSize: 8, weight: .regular)
    dot.contentTintColor = running ? .systemGreen : .systemGray
    let status = NSTextField(labelWithString: running ? "Running" : "Off")

    let header = NSStackView(views: [dot, status])
    header.spacing = 6
    header.edgeInsets = NSEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
    header.frame.size = header.fittingSize
    header.autoresizingMask = [.width]
    return header
  }

  func toggle() {
    if let assertion {
      IOPMAssertionRelease(assertion)
      self.assertion = nil
    } else {
      var identifier: IOPMAssertionID = 0
      let result = IOPMAssertionCreateWithName(
        kIOPMAssertionTypePreventSystemSleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
        "Cafe menu bar app" as CFString, &identifier)
      if result == kIOReturnSuccess { assertion = identifier }
    }
  }

  func updateIcon() {
    let symbol = assertion == nil ? "cup.and.saucer" : "cup.and.saucer.fill"
    statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cafe")
  }
}
