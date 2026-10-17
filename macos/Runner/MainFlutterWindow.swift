import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 900, height: 760))
    self.contentMinSize = NSSize(width: 480, height: 480)
    self.center()
    self.setFrameAutosaveName("AnagramLadderWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
