import AppKit
import Foundation
import SwiftUI

if ProcessInfo.processInfo.environment["RUN_MATH_TESTS"] != nil {
  await runMathTests()
  exit(0)
}

private func defaultTimeline() -> Timeline {
  Timeline(playhead: .zero, inPoint: .zero, outPoint: Fraction(10, 1))
}

@MainActor
struct ContentView: View {
  @State private var timeline = defaultTimeline()
  @State private var selectedClip: VideoClip?
  @State private var importError: String?
  @State private var isPlaying = false
  @State private var isVectorEditing = false

  var body: some View {
    GeometryReader { geometry in
      let fullHeight = max(geometry.size.height, 1)
      let topBarHeight = fullHeight * 0.04
      let canvasHeight = fullHeight * 0.66
      let timelineHeight = fullHeight * 0.30

      VStack(spacing: 0) {
        TopBarView(
          isPlaying: $isPlaying,
          onExport: {
            importError = "Export is not available in the Milestone 6 UI build."
          }
        )
        .frame(height: topBarHeight)

        HSplitView {
          SidebarView(
            timeline: timeline,
            selectedClip: $selectedClip,
            isVectorEditing: $isVectorEditing
          )
          .frame(minWidth: 512, idealWidth: 512, maxWidth: 512)

          VStack(spacing: 0) {
            ZStack {
              EditorTheme.canvasBackground
              PreviewView(timeline: timeline)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .padding(20)
            }
            .frame(height: canvasHeight)

            TimelineView(
              timeline: timeline,
              selectedClip: $selectedClip,
              isPlaying: $isPlaying,
              isVectorEditing: $isVectorEditing,
              onImportError: { importError = $0 }
            )
            .frame(height: timelineHeight)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: canvasHeight + timelineHeight)
      }
      .background(EditorTheme.canvasBackground)
      .overlay(alignment: .topTrailing) {
        if let importError {
          ErrorBanner(message: importError) {
            self.importError = nil
          }
          .padding(.top, topBarHeight + 10)
          .padding(.trailing, 14)
          .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .animation(.easeInOut(duration: 0.18), value: importError)
    }
    .background(EditorTheme.canvasBackground)
  }
}

@MainActor
private struct TopBarView: View {
  @Binding var isPlaying: Bool
  let onExport: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text("Bambuu-variant")
        .font(.system(size: 15, weight: .semibold))
      Spacer()
      Text("1920×1080")
        .font(.caption.monospacedDigit())
        .foregroundStyle(EditorTheme.text.opacity(0.65))
      Button {
        isPlaying.toggle()
      } label: {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .help(isPlaying ? "Pause" : "Play")

      Button(action: onExport) {
        Label("Export", systemImage: "square.and.arrow.up")
          .font(.system(size: 12, weight: .semibold))
          .padding(.horizontal, 11)
          .padding(.vertical, 7)
          .background(EditorTheme.selection)
          .clipShape(RoundedRectangle(cornerRadius: 7))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .foregroundStyle(EditorTheme.text)
    .background(EditorTheme.panelBackground)
  }
}

@MainActor
private struct ErrorBanner: View {
  let message: String
  let dismiss: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(Color(nsColor: .systemOrange))
      Text(message)
        .font(.caption)
        .lineLimit(2)
      Button(action: dismiss) {
        Image(systemName: "xmark")
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .frame(maxWidth: 520)
    .foregroundStyle(EditorTheme.text)
    .background(EditorTheme.panelBackground)
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(EditorTheme.text.opacity(0.12), lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .shadow(radius: 8, y: 3)
  }
}

struct AlightNativeApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1280, height: 832)
  }
}

AlightNativeApp.main()
