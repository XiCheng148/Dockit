import AppKit

let bundleIdentifier = Bundle.main.bundleIdentifier!
let appVersion =
    "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"

BackgroundWork.start()
_ = Applications.shared


private let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = AXIsProcessTrustedWithOptions(
    [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary)
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
