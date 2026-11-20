import CoreGraphics
import Foundation
// Prints "<id> <w>x<h> <title>" for each on-screen window owned by the process with the given pid.
let pid = Int32(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
    let b = w[kCGWindowBounds as String] as! [String: Any]
    print(w[kCGWindowNumber as String]!, "\(b["Width"]!)x\(b["Height"]!)", w[kCGWindowName as String] ?? "")
}
