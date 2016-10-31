/**
*            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
*                    Version 2, December 2004
*
*            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
*   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
*
*  0. You just DO WHAT THE FUCK YOU WANT TO.
*/

/**
* https://github.com/RoxasShadow/usurper
*/

import Cocoa
import Foundation

// https://gist.github.com/rsattar/ed74982428003db8e875
extension Bundle {
  func fakeBundleIdentifier() -> NSString {
    if self == Bundle.main {
      return "dont.mind.me.totally.a.normal.bundleid"
    }
    else {
      return self.fakeBundleIdentifier()
    }
  }
}

class UserNotificationController: NSObject, NSUserNotificationCenterDelegate {
  static let shared = UserNotificationController()

  func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
    if let text = notification.informativeText, let url = URL(string: text) {
      NSWorkspace.shared().open(url)
    }
  }

  func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
    return true
  }

  public func displayNotification(message: String, filename: String) {
    let notification = NSUserNotification()
    notification.identifier = "\(NSDate().timeIntervalSince1970)"
    notification.title      = "Usurper"
    notification.subtitle   = message
    notification.informativeText = filename
    NSUserNotificationCenter.default.deliver(notification)
  }
}

class Usurper: NSObject, NSMetadataQueryDelegate {
  let query  = NSMetadataQuery()
  let events = [
    NSNotification.Name.NSMetadataQueryDidStartGathering,
    NSNotification.Name.NSMetadataQueryDidUpdate,
    NSNotification.Name.NSMetadataQueryDidFinishGathering
  ]

  // Will be overwritten if it's been customized, anyway
  var screenshotsFolder = "~/Desktop/"

  enum ImageServices: String {
    case uguu = "https://www.uguu.se/api.php?d=upload-tool"
    case じ   = "https://jii.moe/api/v1/upload"
    case SCP  = "user@host:my/screenshots/folder"
  }

  // The image service that will be used
  let imageService = ImageServices.SCP

  // The direct URL to the screenshot uploaded with SCP
  let SCPPrefix = "http://my.screenshots.com/folder/"

  // https://gist.github.com/rsattar/ed74982428003db8e875
  func swizzleToReturnANonEmptyBundleIdentifier() -> Bool {
    if let aClass = objc_getClass("NSBundle") as? AnyClass {
      method_exchangeImplementations(
        class_getInstanceMethod(aClass, #selector(getter: Bundle.bundleIdentifier)),
        class_getInstanceMethod(aClass, #selector(Bundle.fakeBundleIdentifier))
      )
      return true
    }
    return false
  }

  override init() {
    super.init()

    // https://gist.github.com/rsattar/ed74982428003db8e875
    let _ = swizzleToReturnANonEmptyBundleIdentifier()

    setCustomScreenshotsFolder()

    for event in events {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(queryUpdated),
        name:   event,
        object: query
      )
    }

    query.delegate  = self
    query.predicate = NSPredicate(format: "kMDItemIsScreenCapture = 1")
  }

  deinit { plsStop() }

  func plsGo() {
    query.start()
  }

  func plsStop()  {
    for event in events {
      NotificationCenter.default.removeObserver(
        self,
        name: event,
        object: query
      )
    }

    query.stop()
  }

  @objc private func queryUpdated(notification: NSNotification) {
    if let userInfo = notification.userInfo {
      for metadata in userInfo.values {
        let items = metadata as! [NSMetadataItem]
        if !items.isEmpty {
          if let filename = items[0].value(forAttribute: "kMDItemFSName") as? String {
            screenshotTaken(filename: normalizeScreenshotFilename(filename: filename))
          }
        }
      }
    }
  }

  private func normalizeScreenshotFilename(filename: String) -> String {
    let newFilename = filename.replacingOccurrences(of: "Screen Shot", with: "Screenshot")
                              .replacingOccurrences(of: " at ", with: " ")
                              .replacingOccurrences(of: "\\s", with: "_",
                                options: .regularExpression,
                                range: nil
                              )

    let path    = NSString(string: screenshotsFolder + filename).expandingTildeInPath
    let newPath = NSString(string: screenshotsFolder + newFilename).expandingTildeInPath

    do {
      try FileManager.default.moveItem(atPath: path, toPath: newPath)
    }
    catch _ as NSError {}

    return newFilename
  }

  private func screenshotTaken(filename: String) {
    let path = NSString(string: screenshotsFolder + filename).expandingTildeInPath

    UserNotificationController.shared.displayNotification(message: "Uploading to \(imageService)...", filename: filename)
    let url = uploadTo(endpoint: imageService.rawValue, file: path, filename: filename)
    copyToPasteboard(content: url)
    UserNotificationController.shared.displayNotification(message: "The URL has been copied into the clipboard", filename: filename)
  }

  private func setCustomScreenshotsFolder() {
    if let location = CFPreferencesCopyAppValue("location" as CFString, "com.apple.screencapture" as CFString) {
      screenshotsFolder = location as! String
    }
  }

  private func copyToPasteboard(content: String) {
    let pasteboard = NSPasteboard.general()
    pasteboard.clearContents()
    pasteboard.writeObjects([content as NSPasteboardWriting])
  }

  // TODO: Use a native implementation
  private func uploadTo(endpoint: String, file: String, filename: String) -> String {
    if imageService == ImageServices.SCP {
      let escapedFilename = filename.replacingOccurrences(of: " ", with: "\\ ",
        options: NSString.CompareOptions.literal,
        range: nil
      )

      let finalDestination = NSString.path(withComponents: [endpoint, escapedFilename])

      let cmd = "scp \"\(file)\" \"\(finalDestination)\""
      let _   = executeCommand(command: cmd)
      return SCPPrefix + filename
    }
    else {
      let cmd = "curl -# --fail --form 'file=@\"\(file)\"' \"\(endpoint)\""
      return executeCommand(command: cmd)
    }
  }

  private func executeCommand(command: String) -> String {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments  = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: String.Encoding.utf8)!

    task.waitUntilExit()
    return output
  }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMetadataQueryDelegate {
  var usurper: Usurper!

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    NSUserNotificationCenter.default.delegate = UserNotificationController.shared

    if let userNotification = aNotification.userInfo?[NSApplicationLaunchUserNotificationKey] as? NSUserNotification {
      UserNotificationController.shared.userNotificationCenter(.default, didActivate: userNotification)
    }

    usurper = Usurper()
    usurper.plsGo()
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    usurper?.plsStop()
  }
}

let app        = NSApplication.shared()
let controller = AppDelegate()

app.delegate = controller
app.run()
