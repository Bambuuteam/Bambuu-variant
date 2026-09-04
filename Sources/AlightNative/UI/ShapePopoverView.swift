import AppKit
import SwiftUI

/// Rectangular slide-out panel for the shape tool.
/// Slides in horizontally from the right edge of the toolbar into the
/// timeline manager zone only (never over the canvas).
@MainActor
struct ShapePopoverView: View {
  @Binding var shapeKind: ShapeKind
  @Binding var shapeColor: Color
  var onSelect: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      LazyVGrid(
        columns: Array(repeating: GridItem(.fixed(40), spacing: 12), count: 2),
        spacing: 12
      ) {
        ForEach(ShapeKind.allCases) { shape in
          Button {
            shapeKind = shape
            onSelect?()
          } label: {
            Image(systemName: shape.systemImage)
              .font(.system(size: 16, weight: .medium))
              .frame(width: 40, height: 40)
              .background(
                shapeKind == shape ? EditorTheme.selection : EditorTheme.canvasBackground
              )
              .clipShape(RoundedRectangle(cornerRadius: 7))
          }
          .buttonStyle(.plain)
          .help(shape.rawValue)
        }
      }
      .frame(maxWidth: .infinity, alignment: .center)

      Divider()

      HStack(spacing: 8) {
        ShapeColorWell(color: $shapeColor)
          .frame(width: 40, height: 40)
        RoundedRectangle(cornerRadius: 4)
          .fill(shapeColor)
          .frame(height: 24)
      }
    }
    .padding(12)
    .frame(width: 180)
    .background(EditorTheme.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(EditorTheme.text.opacity(0.08), lineWidth: 1)
    }
    .shadow(radius: 8, y: 3)
  }
}

/// Minimal NSColorWell wrapper. The well itself lives in the popover;
/// AppKit opens the full NSColorPanel on click.
@MainActor
struct ShapeColorWell: NSViewRepresentable {
  @Binding var color: Color

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeNSView(context: Context) -> NSColorWell {
    let well = NSColorWell()
    well.target = context.coordinator
    well.action = #selector(Coordinator.colorChanged(_:))
    well.color = NSColor(color)
    return well
  }

  func updateNSView(_ nsView: NSColorWell, context: Context) {
    let next = NSColor(color)
    if nsView.color != next {
      nsView.color = next
    }
  }

  @MainActor
  final class Coordinator: NSObject {
    var parent: ShapeColorWell

    init(parent: ShapeColorWell) {
      self.parent = parent
    }

    @objc func colorChanged(_ sender: NSColorWell) {
      parent.color = Color(nsColor: sender.color)
    }
  }
}
