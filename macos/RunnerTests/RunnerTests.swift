import Cocoa
import FlutterMacOS
import XCTest

class RunnerTests: XCTestCase {

  func testApplicationMetadata() {
    XCTAssertEqual(Bundle.main.bundleIdentifier, "com.farblondzshet.anagramladder")
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "Anagram Ladder")
    XCTAssertEqual(
      Bundle.main.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String,
      "public.app-category.word-games"
    )
  }

  func testWindowAndSettingsMenu() {
    let window = NSApplication.shared.windows.first { $0.contentViewController is FlutterViewController }
    XCTAssertNotNil(window)
    XCTAssertEqual(window?.contentMinSize, NSSize(width: 480, height: 480))
    let menu = NSApplication.shared.mainMenu?.items.first?.submenu
    let settings = menu?.items.first { $0.action == NSSelectorFromString("showSettings:") }
    XCTAssertNotNil(settings)
    XCTAssertEqual(settings?.keyEquivalent, ",")
  }

}
