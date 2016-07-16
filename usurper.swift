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
extension NSBundle {
  func fakeBundleIdentifier() -> NSString {
    if self == NSBundle.mainBundle() {
      return "dont.mind.me.totally.a.normal.bundleid"
    }
    else {
      return self.fakeBundleIdentifier()
    }
  }
}

class Usurper: NSObject, NSMetadataQueryDelegate {
  let center = NSNotificationCenter.defaultCenter()
  let query  = NSMetadataQuery()
  let events = [
    NSMetadataQueryDidStartGatheringNotification,
    NSMetadataQueryDidUpdateNotification,
    NSMetadataQueryDidFinishGatheringNotification
  ]

  // Will be overwritten if it's been customized, anyway
  var screenshotsFolder = "~/Desktop/"

  enum ImageServices: String {
    case uguu = "https://www.uguu.se/api.php?d=upload-tool"
    case じ    = "https://jii.moe/api/v1/upload"
    case SCP  = "user@host:my/screenshots/folder"
  }

  // The image service that will be used
  let imageService = ImageServices.uguu

  // The direct URL to the screenshot uploaded with SCP
  let SCPPrefix = "http://my.screenshots.com/folder/"

  // https://gist.github.com/rsattar/ed74982428003db8e875
  func swizzleToReturnANonEmptyBundleIdentifier() -> Bool {
    if let aClass = objc_getClass("NSBundle") as? AnyClass {
      method_exchangeImplementations(
        class_getInstanceMethod(aClass, Selector("bundleIdentifier")),
        class_getInstanceMethod(aClass, #selector(NSBundle.fakeBundleIdentifier))
      )
      return true
    }
    return false
  }

  override init() {
    super.init()

    // https://gist.github.com/rsattar/ed74982428003db8e875
    swizzleToReturnANonEmptyBundleIdentifier()

    setCustomScreenshotsFolder()

    for event in events {
      center.addObserver(
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
    query.startQuery()
  }

  func plsStop()  {
    for event in events {
      center.removeObserver(
        self,
        name: event,
        object: query
      )
    }

    query.stopQuery()
  }

  @objc private func queryUpdated(notification: NSNotification) {
    if let userInfo = notification.userInfo {
      for metadata in userInfo.values {
        let items = metadata as! [NSMetadataItem]
        if !items.isEmpty {
          if let filename = items[0].valueForAttribute("kMDItemFSName") as? String {
            screenshotTaken(normalizeScreenshotFilename(filename))
          }
        }
      }
    }
  }

  private func normalizeScreenshotFilename(filename: String) -> String {
    let newFilename = filename.stringByReplacingOccurrencesOfString("Screen Shot", withString: "Screenshot")
                              .stringByReplacingOccurrencesOfString(" at ", withString: " ")
                              .stringByReplacingOccurrencesOfString("\\s",
                                withString: "_",
                                options: NSStringCompareOptions.RegularExpressionSearch,
                                range: nil
                              )

    let path    = NSString(string: screenshotsFolder + filename).stringByExpandingTildeInPath
    let newPath = NSString(string: screenshotsFolder + newFilename).stringByExpandingTildeInPath

    let fileManager = NSFileManager.defaultManager()
    do {
      try fileManager.moveItemAtPath(path, toPath: newPath)
    }
    catch _ as NSError {}

    return newFilename
  }

  private func screenshotTaken(filename: String) {
    let path = NSString(string: screenshotsFolder + filename).stringByExpandingTildeInPath

    showNotification("Uploading to \(imageService)...", filename: filename)
    let url = uploadTo(imageService.rawValue, file: path, filename: filename)
    copyToPasteboard(url)
    showNotification("The URL has been copied into the clipboard", filename: filename)
  }

  private func setCustomScreenshotsFolder() {
    if let location = CFPreferencesCopyAppValue("location", "com.apple.screencapture") {
      screenshotsFolder = location as! String
    }
  }

  private func copyToPasteboard(content: String) {
    let pasteboard = NSPasteboard.generalPasteboard()
    pasteboard.clearContents()
    pasteboard.writeObjects([content])
  }

  private func showNotification(message: String, filename: String) {
    let notification = NSUserNotification()
    notification.identifier = "\(NSDate().timeIntervalSince1970)"
    notification.title      = "Usurper"
    notification.subtitle   = message
    notification.informativeText = filename
    NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(notification)
  }

  // TODO: Use a native implementation
  private func uploadTo(endpoint: String, file: String, filename: String) -> String {
    if imageService == ImageServices.SCP {
      let escapedFilename = filename.stringByReplacingOccurrencesOfString(" ",
        withString: "\\ ",
        options: NSStringCompareOptions.LiteralSearch,
        range: nil
      )

      let finalDestination = NSString.pathWithComponents([endpoint, escapedFilename])

      let cmd = "scp \"\(file)\" \"\(finalDestination)\""
      executeCommand(cmd)
      return SCPPrefix + filename
    }
    else {
      let cmd = "curl -# --fail --form 'file=@\"\(file)\"' \"\(endpoint)\""
      return executeCommand(cmd)
    }
  }

  private func executeCommand(command: String) -> String {
    let task = NSTask()
    task.launchPath = "/bin/sh"
    task.arguments  = ["-c", command]

    let pipe = NSPipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output: String = NSString(data: data, encoding: NSUTF8StringEncoding) as! String

    task.waitUntilExit()
    return output
  }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMetadataQueryDelegate {
  var usurper: Usurper!

  func applicationDidFinishLaunching(aNotification: NSNotification) {
    usurper = Usurper()
    usurper.plsGo()
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    usurper?.plsStop()
  }
}

let app        = NSApplication.sharedApplication()
let controller = AppDelegate()

app.delegate = controller
app.run()
