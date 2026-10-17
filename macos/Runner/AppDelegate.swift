import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  @IBAction func showSettings(_ sender: Any?) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      NSLog("Could not open settings: Flutter window is unavailable.")
      return
    }
    FlutterMethodChannel(
      name: "anagram_ladder/menu",
      binaryMessenger: controller.engine.binaryMessenger
    ).invokeMethod("settings", arguments: nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
