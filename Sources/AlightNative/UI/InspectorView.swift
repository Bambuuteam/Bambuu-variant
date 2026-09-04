import SwiftUI

@MainActor
struct InspectorView: View {
  @Binding var selectedClip: VideoClip?

  @State private var clipUIState: [UUID: ClipUIState] = [:]
  @State private var effectStacks: [UUID: [EffectStackEntry]] = [:]
  @State private var selectedEffectID: UUID?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if let clip = selectedClip {
          clipHeader(clip)
          transformSection(clip)
          opacitySection(clip)
          timingSection(clip)
          effectStackSection(clip)
          if let effect = selectedEffect(for: clip) {
            effectParametersSection(effect, clipID: clip.id)
          }
          keyframeSection
        } else {
          VStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
              .font(.system(size: 28))
            Text("No clip selected")
              .font(.headline)
            Text("Select a clip in the timeline or library to edit its properties.")
              .font(.caption)
              .multilineTextAlignment(.center)
              .foregroundStyle(EditorTheme.text.opacity(0.6))
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 48)
        }
      }
      .padding(14)
    }
    .background(EditorTheme.panelBackground)
    .foregroundStyle(EditorTheme.text)
    .onChange(of: selectedClip?.id) {
      selectedEffectID = nil
    }
  }

  private func clipHeader(_ clip: VideoClip) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Clip Properties")
        .font(.headline)
      Text(clip.sourceURL.lastPathComponent)
        .font(.caption)
        .lineLimit(1)
        .foregroundStyle(EditorTheme.text.opacity(0.65))
    }
  }

  private func transformSection(_ clip: VideoClip) -> some View {
    propertySection(title: "Transform", systemImage: "move.3d") {
      numericControl(
        title: "Position X",
        value: clipStateBinding(for: clip.id, keyPath: \.positionX),
        range: -2000...2000
      )
      numericControl(
        title: "Position Y",
        value: clipStateBinding(for: clip.id, keyPath: \.positionY),
        range: -2000...2000
      )
      numericControl(
        title: "Scale",
        value: clipStateBinding(for: clip.id, keyPath: \.scale),
        range: 0.01...4
      )
      numericControl(
        title: "Rotation",
        value: clipStateBinding(for: clip.id, keyPath: \.rotation),
        range: -180...180
      )
    }
  }

  private func opacitySection(_ clip: VideoClip) -> some View {
    propertySection(title: "Opacity", systemImage: "circle.lefthalf.filled") {
      numericControl(
        title: "Opacity",
        value: clipStateBinding(for: clip.id, keyPath: \.opacity),
        range: 0...1
      )
    }
  }

  private func timingSection(_ clip: VideoClip) -> some View {
    propertySection(title: "Timing", systemImage: "clock") {
      HStack {
        Text("Start")
        Spacer()
        Text(Self.timecode(clip.startTime.toDouble))
          .monospacedDigit()
      }
      HStack {
        Text("Duration")
        Spacer()
        Text(Self.timecode(clip.duration.toDouble))
          .monospacedDigit()
      }
    }
  }

  private func effectStackSection(_ clip: VideoClip) -> some View {
    propertySection(title: "Effect Stack", systemImage: "square.3.layers.3d") {
      Text("Top of list is applied first")
        .font(.caption2)
        .foregroundStyle(EditorTheme.text.opacity(0.55))

      let effects = effectStacks[clip.id] ?? []
      if effects.isEmpty {
        Text("No effects")
          .font(.caption)
          .foregroundStyle(EditorTheme.text.opacity(0.55))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 8)
      } else {
        List {
          ForEach(effects) { effect in
            Button {
              selectedEffectID = effect.id
            } label: {
              HStack(spacing: 8) {
                Image(systemName: effect.systemImage)
                Text(effect.name)
                  .lineLimit(1)
                Spacer()
                if selectedEffectID == effect.id {
                  Image(systemName: "checkmark")
                }
              }
              .padding(.vertical, 3)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
          .onMove { source, destination in
            moveEffects(for: clip.id, from: source, to: destination)
          }
        }
        .scrollContentBackground(.hidden)
        .background(EditorTheme.canvasBackground)
        .frame(minHeight: 110, maxHeight: 210)
      }

      Menu {
        Button("Color Correction") {
          addEffect(name: "Color Correction", systemImage: "slider.horizontal.3", to: clip.id)
        }
        Button("Gaussian Blur") {
          addEffect(name: "Gaussian Blur", systemImage: "drop.halffull", to: clip.id)
        }
        Button("Sharpen") {
          addEffect(name: "Sharpen", systemImage: "camera.filters", to: clip.id)
        }
        Button("Vignette") {
          addEffect(name: "Vignette", systemImage: "circle.dotted", to: clip.id)
        }
      } label: {
        Label("Add Effect", systemImage: "plus")
          .frame(maxWidth: .infinity)
      }
      .menuStyle(.borderlessButton)
    }
  }

  private func effectParametersSection(_ effect: EffectStackEntry, clipID: UUID) -> some View {
    propertySection(title: effect.name, systemImage: effect.systemImage) {
      numericControl(
        title: "Intensity",
        value: Binding(
          get: { selectedEffect(for: clipID)?.intensity ?? effect.intensity },
          set: { newValue in
            updateEffect(effect.id, clipID: clipID) { $0.intensity = newValue }
          }
        ),
        range: 0...1
      )
      HStack {
        Text("Blend Mode")
        Spacer()
        Picker(
          "Blend Mode",
          selection: Binding(
            get: { selectedEffect(for: clipID)?.blendMode ?? effect.blendMode },
            set: { newMode in
              updateEffect(effect.id, clipID: clipID) { $0.blendMode = newMode }
            }
          )
        ) {
          ForEach(BlendMode.allCases) { mode in
            Text(mode.rawValue).tag(mode)
          }
        }
        .labelsHidden()
        .frame(width: 150)
      }
    }
  }

  private var keyframeSection: some View {
    propertySection(title: "Keyframes", systemImage: "point.3.filled.connected.trianglepath.dotted")
    {
      KeyframeGraphView(clip: $selectedClip)
        .frame(maxWidth: .infinity, alignment: .center)
    }
  }

  private func propertySection<Content: View>(
    title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: systemImage)
        .font(.system(size: 13, weight: .semibold))
      content()
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EditorTheme.canvasBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private func numericControl(
    title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(title)
          .font(.caption)
        Spacer()
        Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
          .font(.caption.monospacedDigit())
          .foregroundStyle(EditorTheme.text.opacity(0.65))
      }
      Slider(value: value, in: range)
        .tint(EditorTheme.selection)
    }
  }

  private func clipStateBinding(
    for clipID: UUID,
    keyPath: WritableKeyPath<ClipUIState, Double>
  ) -> Binding<Double> {
    Binding(
      get: {
        let state = clipUIState[clipID] ?? ClipUIState()
        return state[keyPath: keyPath]
      },
      set: { newValue in
        var state = clipUIState[clipID] ?? ClipUIState()
        state[keyPath: keyPath] = newValue
        clipUIState[clipID] = state
      }
    )
  }

  private func addEffect(name: String, systemImage: String, to clipID: UUID) {
    let effect = EffectStackEntry(name: name, systemImage: systemImage)
    effectStacks[clipID, default: []].append(effect)
    selectedEffectID = effect.id
  }

  private func moveEffects(for clipID: UUID, from source: IndexSet, to destination: Int) {
    var effects = effectStacks[clipID] ?? []
    effects.move(fromOffsets: source, toOffset: destination)
    effectStacks[clipID] = effects
  }

  private func selectedEffect(for clip: VideoClip) -> EffectStackEntry? {
    selectedEffect(for: clip.id)
  }

  private func selectedEffect(for clipID: UUID) -> EffectStackEntry? {
    guard let selectedEffectID else { return nil }
    return effectStacks[clipID]?.first(where: { $0.id == selectedEffectID })
  }

  private func updateEffect(
    _ effectID: UUID,
    clipID: UUID,
    update: (inout EffectStackEntry) -> Void
  ) {
    guard var effects = effectStacks[clipID],
      let index = effects.firstIndex(where: { $0.id == effectID })
    else { return }
    update(&effects[index])
    effectStacks[clipID] = effects
  }

  private static func timecode(_ seconds: Double) -> String {
    let safeSeconds = max(seconds, 0)
    let hours = Int(safeSeconds) / 3600
    let minutes = (Int(safeSeconds) / 60) % 60
    let wholeSeconds = Int(safeSeconds) % 60
    let frames = Int((safeSeconds - floor(safeSeconds)) * 30.0)
    return String(format: "%d:%02d:%02d:%02d", hours, minutes, wholeSeconds, frames)
  }
}

private struct ClipUIState {
  var positionX: Double = 0
  var positionY: Double = 0
  var scale: Double = 1
  var rotation: Double = 0
  var opacity: Double = 1
}

private struct EffectStackEntry: Identifiable, Equatable {
  let id = UUID()
  let name: String
  let systemImage: String
  var intensity: Double = 1
  var blendMode: BlendMode = .normal
}

private enum BlendMode: String, CaseIterable, Identifiable {
  case normal = "Normal"
  case multiply = "Multiply"
  case screen = "Screen"
  case overlay = "Overlay"

  var id: Self { self }
}

@MainActor
struct VectorPropertiesView: View {
  @State private var nodeX = 0.0
  @State private var nodeY = 0.0
  @State private var strokeWidth = 1.0
  @State private var fillOpacity = 1.0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Label("Vector Properties", systemImage: "pencil.tip.crop.circle")
          .font(.headline)

        vectorSection(
          title: "Node", systemImage: "point.topleft.down.to.point.bottomright.curvepath.dotted"
        ) {
          vectorControl(title: "X", value: $nodeX, range: -2000...2000)
          vectorControl(title: "Y", value: $nodeY, range: -2000...2000)
        }

        vectorSection(title: "Path", systemImage: "scribble.variable") {
          vectorControl(title: "Stroke Width", value: $strokeWidth, range: 0...100)
          vectorControl(title: "Fill Opacity", value: $fillOpacity, range: 0...1)
        }
      }
      .padding(14)
    }
    .background(EditorTheme.panelBackground)
    .foregroundStyle(EditorTheme.text)
  }

  private func vectorSection<Content: View>(
    title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: systemImage)
        .font(.system(size: 13, weight: .semibold))
      content()
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EditorTheme.canvasBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private func vectorControl(
    title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(title)
          .font(.caption)
        Spacer()
        Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
          .font(.caption.monospacedDigit())
          .foregroundStyle(EditorTheme.text.opacity(0.65))
      }
      Slider(value: value, in: range)
        .tint(EditorTheme.selection)
    }
  }
}
