# Milestone 6 UI Redesign — Import Log + QA Failure Report

Branch: `feature/ui-redesign` (based on `104fdd5` fix/import-async-race)
Date: 2026-09-04
Author of Milestone 6 implementation: ChatGPT (external session, Linux runtime, no repo write access)
Importer/reviewer: opencode (this session)
QA tester: Shiva (visual + functional stress test on macOS, 1 clip imported)

---

## 1. What ChatGPT delivered (per its own summary)

Local branch: `feature/ui-redesign`, commit `c9e04c5e0f28d6904a4934f4c98b06c3c6d90c41` (exists only in ChatGPT's
sandbox — NOT in this repo, object unknown here).

Changed files (5):
- Added `Sources/AlightNative/UI/SidebarView.swift` (library + properties tabs, thumbnails, vector properties)
- Added `Sources/AlightNative/UI/EditorTheme.swift` (5 hex colors centralized)
- Reworked `Sources/AlightNative/main.swift` (TopBar, transport, error banner, canvas/timeline split)
- Reworked `Sources/AlightNative/UI/TimelineView.swift` (layer controls, transport, zoom, audio meters,
  slide-out tool panels, vector-edit toolbar, AVFoundation thumbnails, effect-stack reordering)
- Reworked `Sources/AlightNative/UI/InspectorView.swift` (transform/opacity/timing sections, effect stack,
  vector properties)

Claimed preserved: scrub/skimmer/playhead logic, drag-drop import, overlap snap, error handling.
Claimed: only the five specified hex colors added; no new `fatalError`; protected paths untouched;
drag/drop uses current session-based API; thumbnails use async `AVAssetImageGenerator.image(at:)`;
razor cursor uses current `NSCursor(image:hotSpot:)`.
Export intentionally omitted (banner: "Export is not available in the Milestone 6 UI build") per
"no placeholder implementations" rule.
Claimed `swift-format` lint, `git diff --check`, Swift parsing pass. Admitted `swift build` NOT run
(Linux runtime, cannot link SwiftUI/AppKit/Metal/AVFoundation).

Delivered as: `~/Downloads/Bambuu-Milestone6-ui-redesign.patch` + `~/Downloads/Bambuu-Milestone6-ui-redesign.zip`

---

## 2. What the importer (opencode) did

### 2a. Patch would not apply
`git apply --check` on the ChatGPT patch FAILED on all 3 modified files
(InspectorView, TimelineView, main.swift). Root cause: ChatGPT's base blob hashes
(`21c9bda`, `73b4097`, `44150fa`) match neither `main` (`77cdcdb`) nor
`fix/import-async-race` (`104fdd5`) — it worked from a divergent snapshot.
So the ZIP (full final files) was used instead of the patch.

### 2b. Import steps
1. Created `feature/ui-redesign` from `104fdd5` (to keep the async-import/race fix).
2. Copied the 5 ZIP files over the working tree.
3. Fixed regressions found by inspection (see 2c).
4. Fixed build errors found by `swift build -c release` (see 2d).
5. Verified: build passes, `RUN_MATH_TESTS=1` 9/9 PASS, `git diff --check` clean,
   no `fatalError` in touched files, exactly 5 hex colors (all in EditorTheme.swift).
6. Committed as `0e8a10a`. Review patch exported to
   `~/Downloads/Bambuu-M6-imported-review.patch` (diff `104fdd5..HEAD`).
7. Refreshed the gitignored `AlightNative.app` bundle with the new release binary and launched it.

### 2c. Regressions fixed before build (ChatGPT silently reverted `fix/import-async-race`)
- `TimelineView.handleDropOnEmpty`: `try VideoClip.make` → `try await VideoClip.make`
  (`VideoClip.make` is `async` since 104fdd5; sync call would not compile).
- `TimelineView.handleDrop`: same missing `await` fix, PLUS restored the live-track lookup
  (`trackID` capture + `timeline.tracks.firstIndex(where:)` before mutation) instead of ChatGPT's
  stale `trackCopy = track` pattern that 104fdd5 deliberately removed.
- `main.swift`: `runMathTests()` → `await runMathTests()` (`runMathTests` is `async`).

### 2d. Build errors fixed (`swift build -c release`, macOS SDK)
- `.dropDestination(for: URL.self, isEnabled: true) { urls, session in ... session.location ... }`
  does not exist in this SDK (2 sites: track lane + empty-timeline view). Reverted to the
  Milestone 5 pattern that compiles: `.dropDestination(for: URL.self) { urls, location in ... return Bool }`.
  ChatGPT's "current session-based API" claim was wrong for this toolchain.
- `popoverY`: `CGFloat(6 * 40 + 5 * 12 + 16)` caused "unable to type-check in reasonable time".
  Replaced with literal `316` and split arithmetic.
- Pre-existing warning (not Milestone 6): `FrameProvider.swift:29` `copyCGImage(at:actualTime:)`
  deprecated in macOS 15. Left untouched.

---

## 3. User QA report (visual + functional, 1 clip imported) — VERDICT: FAIL

Overall: UI is "completely wrong, all over the place", "not even close to the real thing",
"nothing like the mock design". Colors mildly correct; layout completely wrong.

### Layout (all wrong vs mock)
- [ ] Sidebar (Library/Properties) is on the LEFT; per mock it belongs on the RIGHT side.
- [ ] Import/media panel: per mock it sits LEFT of the viewer. Currently imports land in "Library",
  which is wrong content (Library is for presets/effects/scripts/color correction+grading,
  not imported video) and wrong place.
- [ ] Library panel shows user imports — wrong content and wrong dock position.
- [ ] Viewer transport (play etc.) is in the wrong place. Per mock, playback/zoom/resolution
  controls live INSIDE the viewer panel (bottom of viewer), above the timeline — not in a top bar.
- [ ] Import panel and Library/Properties panels must end BEFORE the timeline area
  (must not occupy vertical space in the timeline zone). Currently they clip into it.
- [ ] Toolbar OVERLAPS the track manager: toolbar is oversized, sits on top of the manager,
  hiding most track-manager buttons → both toolbar and manager are practically unusable.
- [ ] Toolbar is clipped top (select tool barely visible) and bottom (runs off-screen).

### Tools (toolbar popovers open, but no function)
- [ ] Magnet icon MISSING entirely.
- [ ] Cut/razor tool does NOT cut.
- [ ] Select tool + others show popovers, but popover contents have no functionality.
- [ ] Shapes: popover opens, shapes do NOT work, and shape UI is poor.

### Timeline / zoom / audio
- [ ] Zoom: only ONE zoom control, at the bottom. It does NOT zoom the timeline the way editors do
  (non-destructive timeline-scale zoom revealing more frames per clip for precision). What it does
  instead resembles stretching the clip. Wrong behavior and wrong placement (mock: horizontal +
  vertical zoom controls for the timeline).
- [ ] Audio: does NOT work. Audio meters appear to animate/glitch with NO actual audio playing
  (fake visualization). Unknown buttons next to the audio controls with no discernible purpose.
- [ ] Timeline itself is "more or less preserved" (playhead/scrub/tracks survived) — the one
  positive note.

### Export
- [ ] Export button non-functional by design in this build (shows "Export is not available in the
  Milestone 6 UI build" banner). Tester confirms it does nothing. Needs a real export pipeline
  decision (out of Milestone 6 scope, but must not ship as a dead button).

### Reference to mock
- The mock design is the source of truth for: panel dock positions (viewer right, imports left of
  viewer, library+properties right, all ending above the timeline zone), transport inside viewer
  panel, timeline zoom semantics, toolbar placement clear of the track manager. The current build
  matches it only in color palette.

---

## 4. Handoff asks for Claude (code review + fix)

1. Reconcile layout with the mock: dock Library/Properties right, imports left-of-viewer,
   both panels ending above the timeline; transport inside viewer panel; toolbar clear of the
   track manager with no clipping.
2. Restore/implement tool function: magnet (icon + snap toggle), razor cut, select, shapes —
   popovers alone are not functionality.
3. Implement editor-standard timeline zoom (H + V, non-destructive scale) replacing the current
   clip-stretch behavior.
4. Fix audio: real playback + meters driven by actual levels (remove fake animation); label or
   remove the mystery buttons next to audio controls.
5. Decide export: either wire a real pipeline or remove the dead button (no placeholders per
   brief — banner is not a shippable state).
6. Keep preserved (do not regress): scrub/skimmer/playhead, drag-drop import, overlap snap,
   error UI, async `VideoClip.make` + live-track race fix from `104fdd5`.
7. Constraints still hold: 5 hex colors max (centralized), no new `fatalError`, protected
   paths (Math/Keyframe/Renderer/Timeline model) untouched.
