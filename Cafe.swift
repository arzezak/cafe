import AppKit
import IOKit.pwr_mgt
import ServiceManagement

@main
@MainActor
final class Cafe: NSObject, NSApplicationDelegate, NSMenuDelegate {
  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  let menu = NSMenu()
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
    menu.delegate = self
    if let button = statusItem.button {
      button.target = self
      button.action = #selector(handleClick)
      button.sendAction(on: [.leftMouseDown, .rightMouseUp])
    }
    updateIcon()
  }

  @objc func handleClick() {
    if NSApp.currentEvent?.type == .rightMouseUp {
      toggle()
    } else {
      statusItem.menu = menu
      statusItem.button?.performClick(nil)
      statusItem.menu = nil
    }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    let header = NSMenuItem()
    header.view = headerView()

    let item = NSMenuItem()
    let awake = assertion != nil
    item.view = Row(image: badge(awake ? "cup.and.saucer.fill" : "cup.and.saucer", on: awake), title: "Keep Awake") {
      [unowned self] in toggle()
    }

    let login = NSMenuItem()
    login.view = Row(image: badge("power", on: SMAppService.mainApp.status == .enabled), title: "Open at Login") {
      [unowned self] in toggleLogin()
    }

    menu.removeAllItems()
    menu.addItem(header)
    menu.addItem(.separator())
    menu.addItem(item)
    menu.addItem(login)
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Quit Cafe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
  }

  func headerView() -> NSView {
    let title = NSTextField(labelWithString: "Cafe")
    title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
    let status = NSTextField(labelWithString: assertion == nil ? "Off" : "On")
    status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    status.textColor = .secondaryLabelColor

    let header = NSStackView(views: [title, status])
    header.orientation = .vertical
    header.alignment = .leading
    header.spacing = 1
    header.edgeInsets = NSEdgeInsets(top: 4, left: 14, bottom: 6, right: 14)
    header.frame.size = header.fittingSize
    header.autoresizingMask = [.width]
    return header
  }

  func badge(_ name: String, on: Bool) -> NSImage {
    let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
      .applying(.init(paletteColors: [on ? .white : .secondaryLabelColor]))
    let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
      .withSymbolConfiguration(configuration)!
    return NSImage(size: NSSize(width: 26, height: 26), flipped: false) { rect in
      (on ? NSColor.controlAccentColor : NSColor.quaternaryLabelColor).setFill()
      NSBezierPath(ovalIn: rect).fill()
      let size = symbol.size
      symbol.draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
      return true
    }
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

  func toggleLogin() {
    let service = SMAppService.mainApp
    do {
      try service.status == .enabled ? service.unregister() : service.register()
    } catch {
      NSLog("Open at Login: \(error.localizedDescription)")
    }
  }

  func updateIcon() {
    let symbol = assertion == nil ? "cup.and.saucer" : "cup.and.saucer.fill"
    statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cafe")
  }
}

final class Row: NSView {
  let action: () -> Void

  init(image: NSImage, title: String, action: @escaping () -> Void) {
    self.action = action
    let stack = NSStackView(views: [NSImageView(image: image), NSTextField(labelWithString: title)])
    stack.spacing = 8
    stack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
    stack.frame = NSRect(origin: NSPoint(x: 0, y: 3), size: stack.fittingSize)
    stack.autoresizingMask = [.width]
    super.init(frame: stack.frame.insetBy(dx: 0, dy: -3))
    autoresizingMask = [.width]
    addSubview(stack)
  }

  required init?(coder: NSCoder) { fatalError() }

  override func draw(_ dirtyRect: NSRect) {
    guard enclosingMenuItem?.isHighlighted == true else { return }
    NSColor.labelColor.withAlphaComponent(0.1).setFill()
    NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 8, yRadius: 8).fill()
  }

  override func mouseUp(with event: NSEvent) {
    enclosingMenuItem?.menu?.cancelTracking()
    action()
  }
}
