import AppKit
import Foundation
import SwiftUI

@MainActor
struct TimelineView: View {
  @Bindable var timeline: Timeline
  @Binding var selectedClip: VideoClip?
  @Binding var isPlaying: Bool
  @Binding var isVectorEditing: Bool
  var onImportError: ((String) -> Void)?

  @State private var searchQuery = ""
  @State private var horizontalZoom = 1.0
  @State private var rowHeight = 52.0
  @State private var layerStates: [UUID: LayerUIState] = [:]
  @State private var motionBlurEnabled = false
  @State private var adjustmentLayerEnabled = false
  @State private var threeDLayerEnabled = false

  @State private var activeTool: PrimaryTool = .select
  @State private var activePopover: ToolPopover?
  @State private var vectorTool: VectorTool = .moveNode
  @State private var selectMode: SelectionMode = .select
  @State private var textMode: TextMode = .text
  @State private var shapeKind: ShapeKind = .square
  @State private var selectedSwatchIndex = 0
  @State private var snapOptions: Set<SnapOption> = Set(SnapOption.allCases)
  @State private var isPointerInsideTimeline = false

  private let layerHeaderWidth: CGFloat = 250
  private let verticalSliderWidth: CGFloat = 34
  private let audioMeterWidth: CGFloat = 76
  private let rulerHeight: CGFloat = 34
  private let transportHeight: CGFloat = 38

  private var totalSeconds: Double {
    max(timeline.outPoint.toDouble, 1.0)
  }

  private var tickSeconds: [Int] {
    let end = Int(timeline.outPoint.toDouble)
    return end >= 0 ? Array(0...end) : []
  }

  private var displayTracks: [DisplayTrack] {
    let normalized = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return timeline.tracks.enumerated().compactMap { index, track in
      let item = DisplayTrack(index: index, track: track)
      guard !normalized.isEmpty else { return item }
      let layerName = "layer \(index + 1)"
      let matchesLayer = layerName.contains(normalized)
      let matchesClip = track.clips.contains {
        $0.sourceURL.lastPathComponent.lowercased().contains(normalized)
      }
      return matchesLayer || matchesClip ? item : nil
    }
  }

  private func fraction(atX x: CGFloat, width: CGFloat) -> Fraction {
    let frac = min(max(x / max(width, 1), 0), 1)
    return Fraction(Int64(frac * totalSeconds * 1000), 1000)
  }

  private func xPosition(of time: Fraction, width: CGFloat) -> CGFloat {
    width * time.toDouble / totalSeconds
  }

  var body: some View {
    GeometryReader { geometry in
      let laneViewportWidth = max(
        geometry.size.width - layerHeaderWidth - verticalSliderWidth - audioMeterWidth,
        1
      )
      let contentWidth = max(laneViewportWidth * horizontalZoom, laneViewportWidth)

      ZStack(alignment: .topLeading) {
        EditorTheme.canvasBackground

        VStack(spacing: 0) {
          HStack(alignment: .top, spacing: 0) {
            layerColumn
              .frame(width: layerHeaderWidth)

            ScrollView(.horizontal) {
              VStack(spacing: 0) {
                ruler(width: contentWidth)
                  .frame(width: contentWidth, height: rulerHeight)

                TransportControls(
                  timeline: timeline,
                  isPlaying: $isPlaying
                )
                .frame(width: contentWidth, height: transportHeight)

                if displayTracks.isEmpty && timeline.tracks.isEmpty {
                  EmptyTimelineDropView(
                    onDrop: { url in
                      handleDropOnEmpty(url: url)
                    }
                  )
                  .frame(width: contentWidth, height: max(rowHeight * 1.7, 90))
                } else {
                  ForEach(displayTracks) { item in
                    TrackLaneView(
                      track: item.track,
                      totalSeconds: totalSeconds,
                      xPosition: xPosition,
                      fraction: fraction,
                      selectedClip: $selectedClip,
                      timeline: timeline,
                      rowHeight: rowHeight,
                      onImportError: onImportError
                    )
                    .frame(width: contentWidth, height: rowHeight)
                  }
                }
              }
              .frame(minWidth: laneViewportWidth, alignment: .leading)
            }
            .scrollIndicators(.hidden)

            VerticalZoomSlider(rowHeight: $rowHeight)
              .frame(width: verticalSliderWidth)

            AudioMeterView(isPlaying: isPlaying)
              .frame(width: audioMeterWidth)
          }
          .frame(maxHeight: .infinity, alignment: .top)

          HStack(spacing: 10) {
            Spacer()
              .frame(width: layerHeaderWidth)
            Image(systemName: "minus.magnifyingglass")
            Slider(value: $horizontalZoom, in: 1...8)
              .tint(EditorTheme.selection)
            Image(systemName: "plus.magnifyingglass")
            Text("\(horizontalZoom, specifier: "%.1f")×")
              .font(.caption.monospacedDigit())
              .frame(width: 40, alignment: .trailing)
            Spacer()
              .frame(width: verticalSliderWidth + audioMeterWidth)
          }
          .font(.caption)
          .foregroundStyle(EditorTheme.text.opacity(0.72))
          .padding(.horizontal, 8)
          .padding(.vertical, 6)
          .background(EditorTheme.rulerBackground)
        }

        if activePopover != nil {
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
              withAnimation(.easeOut(duration: 0.16)) {
                activePopover = nil
              }
            }
        }

        if let activePopover {
          ToolPopoverPanel(
            kind: activePopover,
            selectMode: $selectMode,
            textMode: $textMode,
            shapeKind: $shapeKind,
            selectedSwatchIndex: $selectedSwatchIndex,
            snapOptions: $snapOptions
          )
          .frame(width: 236)
          .position(
            x: 20 + 40 + 12 + 118,
            y: popoverY(for: activePopover, in: geometry.size.height)
          )
          .transition(.move(edge: .leading).combined(with: .opacity))
          .zIndex(2)
        }

        Group {
          if isVectorEditing {
            VectorToolbar(
              activeTool: $vectorTool,
              onBack: {
                withAnimation(.easeInOut(duration: 0.16)) {
                  isVectorEditing = false
                }
              },
              onForward: {
                isVectorEditing = true
              }
            )
          } else {
            PrimaryToolbar(
              activeTool: $activeTool,
              activePopover: $activePopover,
              onVectorPen: {
                activePopover = nil
                withAnimation(.easeInOut(duration: 0.16)) {
                  isVectorEditing = true
                }
              }
            )
          }
        }
        .padding(8)
        .background(EditorTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 8, y: 3)
        .position(
          x: 20 + 20,
          y: geometry.size.height / 2
        )
        .zIndex(3)
      }
      .foregroundStyle(EditorTheme.text)
      .clipped()
      .onHover { inside in
        isPointerInsideTimeline = inside
        updateCursor(inside: inside)
      }
      .onChange(of: activeTool) {
        updateCursor(inside: isPointerInsideTimeline)
      }
      .onChange(of: isVectorEditing) {
        updateCursor(inside: isPointerInsideTimeline)
      }
      .task(id: isPlaying) {
        guard isPlaying else { return }
        let frameStep = Fraction(1, 30)
        while !Task.isCancelled && isPlaying {
          try? await Task.sleep(for: .milliseconds(33))
          guard isPlaying else { break }
          let next = timeline.playhead + frameStep
          if timeline.outPoint <= next {
            timeline.playhead = timeline.outPoint
            isPlaying = false
            break
          }
          timeline.playhead = next
        }
      }
    }
  }

  private var layerColumn: some View {
    VStack(spacing: 0) {
      LayerControlHeader(
        searchQuery: $searchQuery,
        motionBlurEnabled: $motionBlurEnabled,
        adjustmentLayerEnabled: $adjustmentLayerEnabled,
        threeDLayerEnabled: $threeDLayerEnabled
      )
      .frame(height: rulerHeight + transportHeight)

      ForEach(displayTracks) { item in
        LayerHeaderView(
          index: item.index,
          track: item.track,
          state: layerStateBinding(for: item.track.id)
        )
        .frame(height: rowHeight)
      }
    }
    .background(EditorTheme.panelBackground)
  }

  private func ruler(width: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      UnevenRoundedRectangle(
        topLeadingRadius: 8,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 8
      )
      .fill(EditorTheme.rulerBackground)

      ForEach(tickSeconds, id: \.self) { second in
        let x = width * Double(second) / totalSeconds
        Rectangle()
          .fill(EditorTheme.text.opacity(second % 5 == 0 ? 0.65 : 0.32))
          .frame(width: 1, height: second % 5 == 0 ? 10 : 6)
          .position(x: x, y: second % 5 == 0 ? 5 : 3)

        if second % max(labelStride(for: width), 1) == 0 {
          Text(Self.timecode(seconds: second))
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(EditorTheme.text.opacity(0.7))
            .position(x: x + 24, y: 19)
        }
      }

      if let skimmer = timeline.skimmer {
        Rectangle()
          .fill(Color(nsColor: .systemYellow))
          .frame(width: 1, height: rulerHeight)
          .position(x: xPosition(of: skimmer, width: width), y: rulerHeight / 2)
      }

      Rectangle()
        .fill(Color(nsColor: .systemRed))
        .frame(width: 2, height: rulerHeight)
        .position(x: xPosition(of: timeline.playhead, width: width), y: rulerHeight / 2)
    }
    .contentShape(Rectangle())
    .onContinuousHover { phase in
      switch phase {
      case .active(let location):
        timeline.skimmer = fraction(atX: location.x, width: width)
      case .ended:
        timeline.skimmer = nil
      @unknown default:
        timeline.skimmer = nil
      }
    }
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          timeline.playhead = fraction(atX: value.location.x, width: width)
        }
    )
  }

  private func labelStride(for width: CGFloat) -> Int {
    let pixelsPerSecond = width / totalSeconds
    if pixelsPerSecond >= 80 { return 1 }
    if pixelsPerSecond >= 36 { return 2 }
    if pixelsPerSecond >= 18 { return 5 }
    return 10
  }

  private func layerStateBinding(for id: UUID) -> Binding<LayerUIState> {
    Binding(
      get: { layerStates[id] ?? LayerUIState() },
      set: { layerStates[id] = $0 }
    )
  }

  private func handleDropOnEmpty(url: URL) {
    Task {
      do {
        let clip = try await VideoClip.make(from: url)
        var newTrack = Track()
        newTrack.insert(clip)
        timeline.tracks.append(newTrack)
        if timeline.outPoint < clip.duration {
          timeline.outPoint = clip.duration
        }
      } catch {
        onImportError?(error.localizedDescription)
      }
    }
  }

  private func popoverY(for popover: ToolPopover, in height: CGFloat) -> CGFloat {
    let primaryHeight: CGFloat = 316
    let top = max((height - primaryHeight) / 2, 8)
    let index: CGFloat
    switch popover {
    case .select: index = 0
    case .magnet: index = 1
    case .text: index = 3
    case .shape: index = 4
    }
    let iconCenter = top + 28 + index * 52
    let lower: CGFloat = 115
    let upper = max(height - 115, 115)
    return min(max(iconCenter, lower), upper)
  }

  private func updateCursor(inside: Bool) {
    guard inside, activeTool == .cut, !isVectorEditing else {
      NSCursor.arrow.set()
      return
    }
    guard let image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Cut") else {
      NSCursor.crosshair.set()
      return
    }
    image.size = NSSize(width: 26, height: 26)
    NSCursor(image: image, hotSpot: NSPoint(x: 4, y: 4)).set()
  }

  private static func timecode(seconds: Int) -> String {
    let hours = max(seconds, 0) / 3600
    let minutes = (max(seconds, 0) / 60) % 60
    let secs = max(seconds, 0) % 60
    return String(format: "%d:%02d:%02d", hours, minutes, secs)
  }
}

private struct DisplayTrack: Identifiable {
  let index: Int
  let track: Track
  var id: UUID { track.id }
}

private let allowedVideoExtensions = Set(["mov", "mp4", "m4v", "avi", "mkv"])

private func isVideoFile(_ url: URL) -> Bool {
  allowedVideoExtensions.contains(url.pathExtension.lowercased())
}

@MainActor
private struct TrackLaneView: View {
  let track: Track
  let totalSeconds: Double
  let xPosition: (Fraction, CGFloat) -> CGFloat
  let fraction: (CGFloat, CGFloat) -> Fraction
  @Binding var selectedClip: VideoClip?
  @Bindable var timeline: Timeline
  let rowHeight: CGFloat
  let onImportError: ((String) -> Void)?

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        EditorTheme.canvasBackground
        Rectangle()
          .fill(EditorTheme.text.opacity(0.035))

        ForEach(track.clips) { clip in
          let width = geometry.size.width * clip.duration.toDouble / totalSeconds
          let x = geometry.size.width * clip.startTime.toDouble / totalSeconds
          ClipBlockView(
            clip: clip,
            isSelected: selectedClip?.id == clip.id
          )
          .frame(width: max(width, 4), height: max(rowHeight - 8, 24))
          .position(
            x: x + max(width, 4) / 2,
            y: rowHeight / 2
          )
          .onTapGesture {
            selectedClip = clip
          }
        }

        if let skimmer = timeline.skimmer {
          Rectangle()
            .fill(Color(nsColor: .systemYellow))
            .frame(width: 1, height: rowHeight)
            .position(x: xPosition(skimmer, geometry.size.width), y: rowHeight / 2)
        }

        Rectangle()
          .fill(Color(nsColor: .systemRed))
          .frame(width: 2, height: rowHeight)
          .position(x: xPosition(timeline.playhead, geometry.size.width), y: rowHeight / 2)
      }
      .contentShape(Rectangle())
      .onContinuousHover { phase in
        switch phase {
        case .active(let location):
          timeline.skimmer = fraction(location.x, geometry.size.width)
        case .ended:
          timeline.skimmer = nil
        @unknown default:
          timeline.skimmer = nil
        }
      }
      .dropDestination(for: URL.self) { urls, location in
        guard let url = urls.first, isVideoFile(url) else { return false }
        handleDrop(url: url, at: location, in: geometry.size.width)
        return true
      }
    }
  }

  private func handleDrop(url: URL, at location: CGPoint, in width: CGFloat) {
    let trackID = track.id
    Task {
      do {
        let clip = try await VideoClip.make(from: url)
        let startTime = fraction(location.x, width)
        var placedClip = VideoClip(
          id: clip.id,
          startTime: startTime,
          duration: clip.duration,
          sourceURL: clip.sourceURL,
          properties: clip.properties
        )

        // Look up live track directly from timeline to avoid stale value copy races
        guard let index = timeline.tracks.firstIndex(where: { $0.id == trackID }) else { return }
        var liveTrack = timeline.tracks[index]
        if liveTrack.clips.contains(where: {
          $0.startTime < placedClip.endTime && placedClip.startTime < $0.endTime
        }) {
          let lastEnd = liveTrack.clips.map(\.endTime).max() ?? .zero
          placedClip = VideoClip(
            id: clip.id,
            startTime: lastEnd,
            duration: clip.duration,
            sourceURL: clip.sourceURL,
            properties: clip.properties
          )
        }

        liveTrack.insert(placedClip)
        timeline.tracks[index] = liveTrack
        if timeline.outPoint < placedClip.endTime {
          timeline.outPoint = placedClip.endTime
        }
      } catch {
        onImportError?(error.localizedDescription)
      }
    }
  }
}

@MainActor
private struct ClipBlockView: View {
  let clip: VideoClip
  let isSelected: Bool

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      HStack(spacing: 1) {
        ForEach(0..<3, id: \.self) { index in
          VideoThumbnailView(
            url: clip.sourceURL,
            seconds: clip.duration.toDouble * Double(index) / 3.0
          )
        }
      }
      .overlay(EditorTheme.selection.opacity(isSelected ? 0.12 : 0.32))

      Text(clip.sourceURL.lastPathComponent)
        .font(.system(size: 9, weight: .medium))
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorTheme.panelBackground.opacity(0.78))
    }
    .background(EditorTheme.selection.opacity(0.55))
    .overlay {
      RoundedRectangle(cornerRadius: 5)
        .stroke(
          isSelected ? EditorTheme.selection : EditorTheme.text.opacity(0.12),
          lineWidth: isSelected ? 2 : 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 5))
  }
}

@MainActor
private struct EmptyTimelineDropView: View {
  let onDrop: (URL) -> Void

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(
          EditorTheme.text.opacity(0.28),
          style: StrokeStyle(lineWidth: 1, dash: [7, 7])
        )
      VStack(spacing: 8) {
        Image(systemName: "arrow.down.doc")
          .font(.system(size: 24))
        Text("Drop video file here")
          .font(.headline)
        Text("MP4, MOV, M4V, AVI, MKV")
          .font(.caption)
          .foregroundStyle(EditorTheme.text.opacity(0.55))
      }
    }
    .padding(8)
    .dropDestination(for: URL.self) { urls, _ in
      guard let url = urls.first, isVideoFile(url) else { return false }
      onDrop(url)
      return true
    }
  }
}

private struct LayerUIState {
  var visible = true
  var audioEnabled = true
  var solo = false
  var locked = false
  var tagIndex = 0
  var shy = false
}

@MainActor
private struct LayerControlHeader: View {
  @Binding var searchQuery: String
  @Binding var motionBlurEnabled: Bool
  @Binding var adjustmentLayerEnabled: Bool
  @Binding var threeDLayerEnabled: Bool

  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
        TextField("Search layers", text: $searchQuery)
          .textFieldStyle(.plain)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(EditorTheme.canvasBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))

      HStack(spacing: 5) {
        headerToggle(
          systemImage: "circle.dotted.circle",
          help: "Motion Blur",
          isOn: $motionBlurEnabled
        )
        headerToggle(
          systemImage: "square.2.layers.3d",
          help: "Adjustment Layer",
          isOn: $adjustmentLayerEnabled
        )
        headerToggle(
          systemImage: "cube",
          help: "3D Layer",
          isOn: $threeDLayerEnabled
        )
        Spacer(minLength: 0)
      }
    }
    .padding(7)
    .background(EditorTheme.panelBackground)
  }

  private func headerToggle(systemImage: String, help: String, isOn: Binding<Bool>) -> some View {
    Button {
      isOn.wrappedValue.toggle()
    } label: {
      Image(systemName: systemImage)
        .frame(width: 24, height: 22)
        .background(isOn.wrappedValue ? EditorTheme.selection : EditorTheme.canvasBackground)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
    .buttonStyle(.plain)
    .help(help)
  }
}

@MainActor
private struct LayerHeaderView: View {
  let index: Int
  let track: Track
  @Binding var state: LayerUIState

  private let tagColors = [
    Color(nsColor: .systemBlue),
    Color(nsColor: .systemGreen),
    Color(nsColor: .systemOrange),
    Color(nsColor: .systemPurple),
    Color(nsColor: .systemPink),
    Color(nsColor: .systemTeal),
  ]

  var body: some View {
    HStack(spacing: 5) {
      Text("\(index + 1)")
        .font(.caption.monospacedDigit())
        .frame(width: 20, alignment: .trailing)
      layerToggle(systemImage: "eye", help: "Visibility", isOn: $state.visible)
      layerToggle(systemImage: "speaker.wave.2", help: "Audio", isOn: $state.audioEnabled)
      layerToggle(systemImage: "circle", help: "Solo", isOn: $state.solo)
      layerToggle(systemImage: "lock", help: "Lock", isOn: $state.locked)
      Button {
        state.tagIndex = (state.tagIndex + 1) % tagColors.count
      } label: {
        RoundedRectangle(cornerRadius: 3)
          .fill(tagColors[state.tagIndex % tagColors.count])
          .frame(width: 18, height: 18)
      }
      .buttonStyle(.plain)
      .help("Tag")
      layerToggle(
        systemImage: "person.crop.circle.badge.minus",
        help: "Shy",
        isOn: $state.shy
      )
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 7)
    .background(EditorTheme.panelBackground)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(EditorTheme.text.opacity(0.06))
        .frame(height: 1)
    }
    .help(track.clips.first?.sourceURL.lastPathComponent ?? "Empty layer")
  }

  private func layerToggle(systemImage: String, help: String, isOn: Binding<Bool>) -> some View {
    Button {
      isOn.wrappedValue.toggle()
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 11))
        .frame(width: 22, height: 22)
        .background(isOn.wrappedValue ? EditorTheme.selection.opacity(0.28) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    .buttonStyle(.plain)
    .help(help)
  }
}

@MainActor
private struct TransportControls: View {
  @Bindable var timeline: Timeline
  @Binding var isPlaying: Bool

  var body: some View {
    HStack(spacing: 14) {
      transportButton(systemImage: "backward.end.fill", help: "Skip to Start") {
        timeline.playhead = timeline.inPoint
      }
      transportButton(systemImage: "backward.fill", help: "Previous Frame") {
        timeline.playhead = maxFraction(timeline.playhead - Fraction(1, 30), timeline.inPoint)
      }
      transportButton(
        systemImage: isPlaying ? "pause.fill" : "play.fill",
        help: isPlaying ? "Pause" : "Play"
      ) {
        isPlaying.toggle()
      }
      transportButton(systemImage: "forward.fill", help: "Next Frame") {
        timeline.playhead = minFraction(timeline.playhead + Fraction(1, 30), timeline.outPoint)
      }
      transportButton(systemImage: "forward.end.fill", help: "Skip to End") {
        timeline.playhead = timeline.outPoint
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EditorTheme.canvasBackground)
  }

  private func transportButton(systemImage: String, help: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: systemImage)
        .frame(width: 24, height: 24)
    }
    .buttonStyle(.plain)
    .help(help)
  }

  private func minFraction(_ lhs: Fraction, _ rhs: Fraction) -> Fraction {
    lhs < rhs ? lhs : rhs
  }

  private func maxFraction(_ lhs: Fraction, _ rhs: Fraction) -> Fraction {
    rhs < lhs ? lhs : rhs
  }
}

@MainActor
private struct VerticalZoomSlider: View {
  @Binding var rowHeight: Double

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "rectangle.compress.vertical")
        .font(.caption)
      Slider(value: $rowHeight, in: 40...92)
        .rotationEffect(.degrees(-90))
        .frame(width: 120)
        .tint(EditorTheme.selection)
      Image(systemName: "rectangle.expand.vertical")
        .font(.caption)
    }
    .frame(maxHeight: .infinity)
    .background(EditorTheme.panelBackground)
  }
}

@MainActor
private struct AudioMeterView: View {
  let isPlaying: Bool
  @State private var pulse = false

  private let segmentCount = 18

  var body: some View {
    VStack(spacing: 5) {
      Text("Audio")
        .font(.caption2)
      HStack(spacing: 4) {
        meter(level: leftLevel)
        meter(level: rightLevel)
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 8)
    }
    .frame(maxHeight: .infinity)
    .background(EditorTheme.panelBackground)
    .onChange(of: isPlaying, initial: true) {
      updatePulse()
    }
  }

  private var leftLevel: Double {
    guard isPlaying else { return 0.06 }
    return pulse ? 0.93 : 0.38
  }

  private var rightLevel: Double {
    guard isPlaying else { return 0.05 }
    return pulse ? 0.78 : 0.29
  }

  private func meter(level: Double) -> some View {
    GeometryReader { geometry in
      VStack(spacing: 2) {
        ForEach((0..<segmentCount).reversed(), id: \.self) { segment in
          let normalized = Double(segment + 1) / Double(segmentCount)
          RoundedRectangle(cornerRadius: 1)
            .fill(
              normalized <= level
                ? segmentColor(normalized)
                : EditorTheme.text.opacity(0.08)
            )
            .frame(
              height: max(
                (geometry.size.height - CGFloat(segmentCount - 1) * 2) / CGFloat(segmentCount), 1))
        }
      }
    }
  }

  private func segmentColor(_ normalized: Double) -> Color {
    if normalized > 0.84 {
      return Color(nsColor: .systemRed)
    }
    if normalized > 0.62 {
      return Color(nsColor: .systemYellow)
    }
    return Color(nsColor: .systemGreen)
  }

  private func updatePulse() {
    if isPlaying {
      pulse = false
      withAnimation(.easeInOut(duration: 0.44).repeatForever(autoreverses: true)) {
        pulse = true
      }
    } else {
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        pulse = false
      }
    }
  }
}

private enum PrimaryTool: Hashable {
  case select
  case magnet
  case cut
  case text
  case shape
  case vectorPen
}

private enum ToolPopover: Hashable {
  case select
  case magnet
  case text
  case shape
}

private enum SelectionMode: String, CaseIterable, Identifiable {
  case select = "Select"
  case handPan = "Hand Pan"
  case grab = "Grab"
  case misc = "Misc"

  var id: Self { self }

  var systemImage: String {
    switch self {
    case .select: return "arrow.up.left"
    case .handPan: return "hand.draw"
    case .grab: return "hand.point.up.left"
    case .misc: return "folder"
    }
  }
}

private enum TextMode: String, CaseIterable, Identifiable {
  case text = "Text"
  case comment = "Comment"

  var id: Self { self }

  var systemImage: String {
    switch self {
    case .text: return "textformat"
    case .comment: return "text.bubble"
    }
  }
}

private enum ShapeKind: String, CaseIterable, Identifiable {
  case square = "Square"
  case circle = "Circle"
  case star = "Star"
  case diamond = "Diamond"

  var id: Self { self }

  var systemImage: String {
    switch self {
    case .square: return "square"
    case .circle: return "circle"
    case .star: return "star"
    case .diamond: return "diamond"
    }
  }
}

private enum SnapOption: String, CaseIterable, Hashable, Identifiable {
  case timeline = "Timeline Snap"
  case trim = "Trim Snap"
  case select = "Select Snap"
  case cut = "Cut Snap"

  var id: Self { self }
}

private enum VectorTool: String, CaseIterable, Identifiable {
  case moveNode = "Move Node"
  case pen = "Pen"
  case bend = "Bend"
  case paintBucket = "Paint Bucket"
  case variableWidth = "Variable Width"

  var id: Self { self }

  var systemImage: String {
    switch self {
    case .moveNode: return "point.topleft.down.to.point.bottomright.curvepath"
    case .pen: return "pencil.tip"
    case .bend: return "point.bottomleft.forward.to.point.topright.scurvepath"
    case .paintBucket: return "paintbrush.pointed"
    case .variableWidth: return "scribble.variable"
    }
  }
}

@MainActor
private struct PrimaryToolbar: View {
  @Binding var activeTool: PrimaryTool
  @Binding var activePopover: ToolPopover?
  let onVectorPen: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      popoverTool(.select, popover: .select, systemImage: "arrow.up.left", help: "Select")
      popoverTool(.magnet, popover: .magnet, systemImage: "magnet", help: "Magnet")
      toolButton(.cut, systemImage: "scissors", help: "Cut") {
        activePopover = nil
        activeTool = .cut
      }
      popoverTool(.text, popover: .text, systemImage: "textformat", help: "Text")
      popoverTool(.shape, popover: .shape, systemImage: "square.on.circle", help: "Shape")
      toolButton(.vectorPen, systemImage: "pencil.tip.crop.circle", help: "Vector Pen") {
        activeTool = .vectorPen
        onVectorPen()
      }
    }
  }

  private func popoverTool(
    _ tool: PrimaryTool,
    popover: ToolPopover,
    systemImage: String,
    help: String
  ) -> some View {
    toolButton(tool, systemImage: systemImage, help: help) {
      activeTool = tool
      withAnimation(.easeOut(duration: 0.16)) {
        activePopover = activePopover == popover ? nil : popover
      }
    }
  }

  private func toolButton(
    _ tool: PrimaryTool,
    systemImage: String,
    help: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .medium))
        .frame(width: 40, height: 40)
        .background(activeTool == tool ? EditorTheme.selection : EditorTheme.canvasBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
    .help(help)
  }
}

@MainActor
private struct VectorToolbar: View {
  @Binding var activeTool: VectorTool
  let onBack: () -> Void
  let onForward: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      ForEach(VectorTool.allCases) { tool in
        Button {
          activeTool = tool
        } label: {
          Image(systemName: tool.systemImage)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 40, height: 40)
            .background(activeTool == tool ? EditorTheme.selection : EditorTheme.canvasBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(tool.rawValue)
      }

      Divider()

      Button(action: onBack) {
        Image(systemName: "chevron.backward")
          .frame(width: 40, height: 40)
          .background(EditorTheme.canvasBackground)
          .clipShape(RoundedRectangle(cornerRadius: 7))
      }
      .buttonStyle(.plain)
      .help("Back to Primary Toolbar")

      Button(action: onForward) {
        Image(systemName: "chevron.forward")
          .frame(width: 40, height: 40)
          .background(EditorTheme.canvasBackground)
          .clipShape(RoundedRectangle(cornerRadius: 7))
      }
      .buttonStyle(.plain)
      .help("Forward to Vector Toolbar")
    }
  }
}

@MainActor
private struct ToolPopoverPanel: View {
  let kind: ToolPopover
  @Binding var selectMode: SelectionMode
  @Binding var textMode: TextMode
  @Binding var shapeKind: ShapeKind
  @Binding var selectedSwatchIndex: Int
  @Binding var snapOptions: Set<SnapOption>

  private let swatches = [
    Color(nsColor: .systemRed),
    Color(nsColor: .systemOrange),
    Color(nsColor: .systemYellow),
    Color(nsColor: .systemGreen),
    Color(nsColor: .systemMint),
    Color(nsColor: .systemTeal),
    Color(nsColor: .systemBlue),
    Color(nsColor: .systemIndigo),
    Color(nsColor: .systemPurple),
    Color(nsColor: .systemPink),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch kind {
      case .select:
        ForEach(SelectionMode.allCases) { mode in
          optionButton(
            title: mode.rawValue,
            systemImage: mode.systemImage,
            isSelected: selectMode == mode
          ) {
            selectMode = mode
          }
        }
      case .magnet:
        ForEach(SnapOption.allCases) { option in
          optionButton(
            title: option.rawValue,
            systemImage: snapOptions.contains(option) ? "checkmark.square.fill" : "square",
            isSelected: snapOptions.contains(option)
          ) {
            if snapOptions.contains(option) {
              snapOptions.remove(option)
            } else {
              snapOptions.insert(option)
            }
          }
        }
      case .text:
        ForEach(TextMode.allCases) { mode in
          optionButton(
            title: mode.rawValue,
            systemImage: mode.systemImage,
            isSelected: textMode == mode
          ) {
            textMode = mode
          }
        }
      case .shape:
        ForEach(ShapeKind.allCases) { shape in
          optionButton(
            title: shape.rawValue,
            systemImage: shape.systemImage,
            isSelected: shapeKind == shape
          ) {
            shapeKind = shape
          }
        }
        Divider()
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(22), spacing: 7), count: 5), spacing: 7)
        {
          ForEach(swatches.indices, id: \.self) { index in
            Button {
              selectedSwatchIndex = index
            } label: {
              Circle()
                .fill(swatches[index])
                .frame(width: 22, height: 22)
                .overlay {
                  if selectedSwatchIndex == index {
                    Circle()
                      .stroke(EditorTheme.text, lineWidth: 2)
                  }
                }
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .padding(10)
    .background(EditorTheme.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(EditorTheme.text.opacity(0.08), lineWidth: 1)
    }
    .shadow(radius: 8, y: 3)
  }

  private func optionButton(
    title: String,
    systemImage: String,
    isSelected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .frame(width: 20)
        Text(title)
        Spacer()
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .background(isSelected ? EditorTheme.selection : EditorTheme.canvasBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
  }
}
