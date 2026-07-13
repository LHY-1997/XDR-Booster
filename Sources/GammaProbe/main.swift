import AppKit
import CoreGraphics
import Foundation

guard let screen = NSScreen.screens.first(where: {
    guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
    return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
}), let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
    fatalError("未找到内置显示器")
}

let displayID = CGDirectDisplayID(number.uint32Value)
var red = [CGGammaValue](repeating: 0, count: 1024)
var green = red
var blue = red
var count: UInt32 = 0
let result = CGGetDisplayTransferByTable(displayID, UInt32(red.count), &red, &green, &blue, &count)
guard result == .success, count > 0 else { fatalError("读取失败：\(result.rawValue)") }
let used = Int(count)
let snapshot: [String: Any] = [
    "samples": used,
    "red": Array(red.prefix(used)),
    "green": Array(green.prefix(used)),
    "blue": Array(blue.prefix(used))
]
if let output = CommandLine.arguments.dropFirst().first {
    let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys])
    try data.write(to: URL(fileURLWithPath: output), options: .atomic)
    print("saved=\(output)")
}
print("samples=\(used) redMax=\(red.prefix(used).max() ?? 0) greenMax=\(green.prefix(used).max() ?? 0) blueMax=\(blue.prefix(used).max() ?? 0)")
