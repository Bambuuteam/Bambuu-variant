import SwiftUI

enum EditorTheme {
  static let canvasBackground = Color(editorHex: 0x1E1E1E)
  static let panelBackground = Color(editorHex: 0x2C2C2C)
  static let selection = Color(editorHex: 0x4C7BFE)
  static let text = Color(editorHex: 0xFFFFFF)
  static let rulerBackground = Color(editorHex: 0x1A1A1A)
}

extension Color {
  fileprivate init(editorHex: UInt32) {
    let red = Double((editorHex >> 16) & 0xFF) / 255.0
    let green = Double((editorHex >> 8) & 0xFF) / 255.0
    let blue = Double(editorHex & 0xFF) / 255.0
    self.init(red: red, green: green, blue: blue)
  }
}
