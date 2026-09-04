import AVFoundation
import SwiftUI

@MainActor
struct SidebarView: View {
  enum Tab: Hashable {
    case library
    case properties
  }

  @Bindable var timeline: Timeline
  @Binding var selectedClip: VideoClip?
  @Binding var isVectorEditing: Bool

  @State private var activeTab: Tab = .library
  @State private var libraryOverrideClipID: UUID?

  var body: some View {
    VStack(spacing: 0) {
      tabBar
      Divider()
      Group {
        switch activeTab {
        case .library:
          LibraryView(timeline: timeline, selectedClip: $selectedClip)
        case .properties:
          if isVectorEditing {
            VectorPropertiesView()
          } else {
            InspectorView(selectedClip: $selectedClip)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(EditorTheme.panelBackground)
    .foregroundStyle(EditorTheme.text)
    .onChange(of: isVectorEditing) {
      guard isVectorEditing else { return }
      withAnimation(.easeInOut(duration: 0.16)) {
        activeTab = .properties
      }
      libraryOverrideClipID = nil
    }
    .onChange(of: selectedClip?.id) {
      guard let clipID = selectedClip?.id else { return }
      if libraryOverrideClipID != clipID {
        withAnimation(.easeInOut(duration: 0.16)) {
          activeTab = .properties
        }
        libraryOverrideClipID = nil
      }
    }
  }

  private var tabBar: some View {
    HStack(spacing: 8) {
      sidebarTabButton(
        tab: .library,
        title: "Library",
        systemImage: "rectangle.stack"
      )
      sidebarTabButton(
        tab: .properties,
        title: "Properties",
        systemImage: "slider.horizontal.3"
      )
      Spacer(minLength: 0)
    }
    .padding(10)
    .background(EditorTheme.panelBackground)
  }

  private func sidebarTabButton(tab: Tab, title: String, systemImage: String) -> some View {
    Button {
      withAnimation(.easeInOut(duration: 0.16)) {
        activeTab = tab
      }
      switch tab {
      case .library:
        libraryOverrideClipID = selectedClip?.id
      case .properties:
        libraryOverrideClipID = nil
      }
    } label: {
      Label(title, systemImage: systemImage)
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(activeTab == tab ? EditorTheme.selection : EditorTheme.canvasBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
  }
}

@MainActor
private struct LibraryView: View {
  @Bindable var timeline: Timeline
  @Binding var selectedClip: VideoClip?

  private let columns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
  ]

  private var clips: [VideoClip] {
    timeline.tracks.flatMap(\.clips)
  }

  var body: some View {
    ScrollView {
      if clips.isEmpty {
        VStack(spacing: 10) {
          Image(systemName: "film.stack")
            .font(.system(size: 30))
          Text("No media imported")
            .font(.headline)
          Text("Drop a video into the timeline to add it to the library.")
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(EditorTheme.text.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
      } else {
        LazyVGrid(columns: columns, spacing: 10) {
          ForEach(clips) { clip in
            Button {
              selectedClip = clip
            } label: {
              VStack(alignment: .leading, spacing: 7) {
                VideoThumbnailView(url: clip.sourceURL, seconds: 0)
                  .frame(height: 112)
                  .clipShape(RoundedRectangle(cornerRadius: 7))
                Text(clip.sourceURL.lastPathComponent)
                  .font(.caption)
                  .lineLimit(1)
                Text(Self.durationText(clip.duration.toDouble))
                  .font(.caption2.monospacedDigit())
                  .foregroundStyle(EditorTheme.text.opacity(0.6))
              }
              .padding(8)
              .background(
                selectedClip?.id == clip.id
                  ? EditorTheme.selection.opacity(0.22)
                  : EditorTheme.canvasBackground
              )
              .overlay {
                RoundedRectangle(cornerRadius: 9)
                  .stroke(
                    selectedClip?.id == clip.id
                      ? EditorTheme.selection
                      : EditorTheme.text.opacity(0.08),
                    lineWidth: 1
                  )
              }
              .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(12)
      }
    }
    .background(EditorTheme.panelBackground)
  }

  private static func durationText(_ seconds: Double) -> String {
    let total = max(Int(seconds.rounded(.down)), 0)
    return String(format: "%d:%02d", total / 60, total % 60)
  }
}

@MainActor
struct VideoThumbnailView: View {
  let url: URL
  var seconds: Double = 0

  @State private var image: CGImage?

  var body: some View {
    ZStack {
      EditorTheme.canvasBackground
      if let image {
        Image(decorative: image, scale: 1)
          .resizable()
          .scaledToFill()
      } else {
        Image(systemName: "film")
          .font(.system(size: 20))
          .foregroundStyle(EditorTheme.text.opacity(0.45))
      }
    }
    .clipped()
    .task(id: ThumbnailRequest(url: url, seconds: seconds)) {
      let asset = AVURLAsset(url: url)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 480, height: 270)
      let requestedTime = CMTime(seconds: max(seconds, 0), preferredTimescale: 600)
      image = try? await generator.image(at: requestedTime).image
    }
  }

  private struct ThumbnailRequest: Hashable {
    let url: URL
    let seconds: Double
  }
}
