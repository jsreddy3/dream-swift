Quick start
git clone https://github.com/your-org/dreamfinder.git
open dreamfinder/Dreamer.xcodeproj        # workspace loads all packages
Add the privacy string once
Targets ▸ iOS App ▸ Info ▸ Privacy – Microphone Usage Description →
“DreamFinder records your dream narration.”
⌘-R on an iPhone or simulator → grant mic permission → tap the big circle.
Stop & Done → audio + JSON now live under Library/Dreams/.
Directory layout
CoreModels/          pure Swift structs (Dream, AudioSegment…)
DomainLogic/         use-cases: Start|Stop|Continue|Complete
Infrastructure/
    AudioRecorderActor.swift
    FileDreamStore.swift
Features/
    CaptureViewModel.swift
    ContentView.swift
DreamerApp/          iOS target, widgets come later
Package dependency graph
                 ┌───────────── DreamerApp (iOS target)
                 │
Features ────────┤
                 │
DomainLogic ─────┤───────────── Infrastructure
                 │
CoreModels ──────┘
Only the layer directly above may import the one below.
Running tests
Layer	Command	Runs on	Notes
Core + store	swift test -p DomainLogic
swift test -p Infrastructure	macOS host	No simulator, < 1 s
AVFoundation	xcodebuild test -scheme InfrastructurePackageTests -destination 'platform=iOS Simulator,name=iPhone 15'	iOS sim	First run needs mic permission; skips if denied
Full UI (manual)	⌘-R	sim / device	Audio plays through host mic in sim
Public contracts (DomainLogic)
Use-case	What it does
StartCaptureDream() → (dreamID, handle)	Creates a new draft dream, starts first recording
StartAdditionalSegment(dreamID) → handle	Begins another clip for the same draft dream
StopCaptureDream(dreamID, handle, order)	Closes the clip; store appends {filename,duration,order}
CompleteDream(dreamID)	Flips dream state → .completed (ready for upload)
Order is supplied by the caller (view-model tracks an integer).
File formats
// Library/Dreams/<dreamID>.json
{
  "id": "513…",
  "created": "2025-06-18T13:02:31Z",
  "state": "completed",
  "title": "Untitled Dream",
  "transcript": null,
  "segments": [
    { "id": "A1…", "filename": "A1.m4a", "duration": 12.4, "order": 0 },
    { "id": "B2…", "filename": "B2.m4a", "duration": 8.1,  "order": 1 }
  ]
}
Extending from here
Milestone	Drop-in spot
Dream list UI	Features ▸ DreamLibraryView, inject FileDreamStore
STT upload	Infrastructure ▸ BackgroundUploaderActor conforming to new Uploader protocol; trigger after CompleteDream
Widgets / Live Activity	App target ▸ WidgetKit using deep-link myapp://record?autorun=1
Vision Pro / Watch capture	New UI targets import the same DomainLogic & Infrastructure
Troubleshooting
Symptom	Fix
Crash “privacy-sensitive data without usage description”	Add NSMicrophoneUsageDescription (see Quick start)
Duration always 0 s	Make sure AudioRecorderActor records let duration = r.currentTime before r.stop()
Files app shows nothing	Data lives in Library; use Xcode ▸ Download Container… or switch store to .documentDirectory for dev.
AV test skips in CI	Pre-grant mic to the simulator once, or accept that the skip keeps CI green.
License
MIT © 2025 DreamFinder contributors.
