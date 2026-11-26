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
  var batteryAssertion: IOPMAssertionID?

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

    if UserDefaults.standard.bool(forKey: "awake") { toggle() }
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
    // Centered by eye: the handle pulls the cup's bounding box to the right of its body.
    item.view = Row(image: badge(cup, on: awake, offset: NSPoint(x: 1, y: -1)), title: "Keep Awake") {
      [unowned self] in toggle()
    }

    let battery = NSMenuItem()
    let batteryGlyph = NSImage(systemSymbolName: "battery.100percent", accessibilityDescription: nil)!
      .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))!
    battery.view = Row(image: badge(batteryGlyph, on: UserDefaults.standard.bool(forKey: "battery")), title: "On Battery") {
      [unowned self] in toggleBattery()
    }

    let power = NSImage(systemSymbolName: "power", accessibilityDescription: nil)!
      .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))!
    let login = NSMenuItem()
    login.view = Row(image: badge(power, on: SMAppService.mainApp.status == .enabled), title: "Open at Login") {
      [unowned self] in toggleLogin()
    }

    menu.removeAllItems()
    menu.addItem(header)
    menu.addItem(.separator())
    menu.addItem(item)
    menu.addItem(battery)
    menu.addItem(login)
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Quit Cafe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
  }

  func headerView() -> NSView {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    let title = NSTextField(labelWithString: "Cafe v\(version)")
    title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

    let header = NSStackView(views: [title])
    header.orientation = .vertical
    header.alignment = .leading
    header.edgeInsets = NSEdgeInsets(top: 4, left: 14, bottom: 6, right: 14)
    header.frame.size = header.fittingSize
    header.autoresizingMask = [.width]
    return header
  }

  func badge(_ glyph: NSImage, on: Bool, offset: NSPoint = .zero) -> NSImage {
    let scale = min(1, 16 / max(glyph.size.width, glyph.size.height))
    let size = NSSize(width: glyph.size.width * scale, height: glyph.size.height * scale)
    let tinted = NSImage(size: size, flipped: false) { rect in
      glyph.draw(in: rect)
      (on ? NSColor.white : NSColor.secondaryLabelColor).set()
      rect.fill(using: .sourceIn)
      return true
    }
    let ink = inkCenter(of: glyph, drawnAt: size)

    return NSImage(size: NSSize(width: 26, height: 26), flipped: false) { rect in
      (on ? NSColor.controlAccentColor : NSColor.quaternaryLabelColor).setFill()
      NSBezierPath(ovalIn: rect).fill()

      // Ink an odd number of pixels tall can't sit on the center. Rounding up centers the power symbol's ring.
      let origin = NSPoint(
        x: ((rect.midX - ink.x) * 2).rounded(.up) / 2 + offset.x,
        y: ((rect.midY - ink.y) * 2).rounded(.up) / 2 + offset.y)

      tinted.draw(in: NSRect(origin: origin, size: size))
      return true
    }
  }

  func inkCenter(of glyph: NSImage, drawnAt size: NSSize) -> NSPoint {
    let pixels = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(ceil(size.width * 2)), pixelsHigh: Int(ceil(size.height * 2)),
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0)!

    pixels.size = NSSize(width: Double(pixels.pixelsWide) / 2, height: Double(pixels.pixelsHigh) / 2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: pixels)
    glyph.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()

    var inkColumns: [Int] = []
    var inkRows: [Int] = []

    for row in 0..<pixels.pixelsHigh {
      for column in 0..<pixels.pixelsWide where pixels.colorAt(x: column, y: row)!.alphaComponent > 0.5 {
        inkColumns.append(column)
        inkRows.append(row)
      }
    }

    guard let left = inkColumns.min(), let right = inkColumns.max(), let top = inkRows.min(), let bottom = inkRows.max() else {
      return NSPoint(x: size.width / 2, y: size.height / 2)
    }

    return NSPoint(x: Double(left + right + 1) / 4, y: Double(pixels.pixelsHigh) / 2 - Double(top + bottom + 1) / 4)
  }

  func toggle() {
    if let assertion {
      IOPMAssertionRelease(assertion)
      self.assertion = nil
    } else {
      assertion = createAssertion(kIOPMAssertionTypePreventSystemSleep)
    }

    UserDefaults.standard.set(assertion != nil, forKey: "awake")
    updateBatteryAssertion()
  }

  func toggleBattery() {
    UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "battery"), forKey: "battery")
    updateBatteryAssertion()
  }

  func updateBatteryAssertion() {
    let wanted = assertion != nil && UserDefaults.standard.bool(forKey: "battery")

    if wanted, batteryAssertion == nil {
      batteryAssertion = createAssertion(kIOPMAssertionTypePreventUserIdleSystemSleep)
    } else if !wanted, let batteryAssertion {
      IOPMAssertionRelease(batteryAssertion)
      self.batteryAssertion = nil
    }
  }

  func createAssertion(_ type: String) -> IOPMAssertionID? {
    var identifier: IOPMAssertionID = 0
    let result = IOPMAssertionCreateWithName(
      type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Cafe menu bar app" as CFString, &identifier)

    return result == kIOReturnSuccess ? identifier : nil
  }

  func toggleLogin() {
    let service = SMAppService.mainApp
    do {
      try service.status == .enabled ? service.unregister() : service.register()
    } catch {
      NSLog("Open at Login: \(error.localizedDescription)")
    }
  }

  var cup: NSImage {
    NSImage(named: assertion == nil ? "CupOff" : "CupOn")!
  }

  func updateIcon() {
    statusItem.button?.image = cup
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
