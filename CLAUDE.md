# Clef Notes — Project Context

## What the app is
Music practice tracker for iOS. Teachers log students, practice sessions, songs, plays, notes, and recordings. Includes a metronome, pitch tuner, pitch ear-training game, stats/streaks, awards, and CloudKit sharing.

- **Bundle ID:** `com.clefnotesapp.Clef-Notes`
- **Current version:** 1.2 (build 5)
- **Deployment target:** iOS 17.0 (project setting); some views use `#available(iOS 18, *)` / `#available(iOS 26, *)` guards
- **Previous App Store version:** 1.1 — this codebase is a large update not yet released

## Key dependencies
| Library | Used for |
|---|---|
| RevenueCat | Subscription management (`SubscriptionManager.swift`) |
| TelemetryDeck | Analytics / event signals |
| AudioKit / SoundpipeAudioKit | Pitch tuner (`PitchTunerViewModel`) |
| TipKit | Contextual onboarding tips |
| PencilKit | Sketch area inside notes |
| NSPersistentCloudKitContainer | Core Data + iCloud sync + CloudKit sharing |

## Architecture
- **Core Data** for all persistence. Managed object subclasses live in `Core Data/` (suffix `CD`).
- **Views** split into `Core Data Views/` (views that take CD objects directly) and `Views/` (feature views, add/edit sheets, etc.).
- **No third-party UI framework** — pure SwiftUI throughout.
- Shared singletons: `AudioManager` (audio session arbitration), `SettingsManager`, `UsageManager`, `SubscriptionManager`, `SessionTimerManager` — all passed via `.environmentObject`.
- `PersistenceController.shared` holds the CloudKit container. `privatePersistentStore` and `sharedPersistentStore` are **optional** (set asynchronously in the `loadPersistentStores` callback — do not force-unwrap them).

## Data model (Core Data entities)
Current model version: `ClefNotesCD_v4`. All `StudentCD` to-many relationships cascade on delete.

`StudentCD` → has many `PracticeSessionCD`, `SongCD`, `NoteCD`, `InstructorCD`, `AudioRecordingCD`, `MediaReferenceCD`, `EarnedAwardCD`  
`PracticeSessionCD` → has many `PlayCD`, `NoteCD`, `AudioRecordingCD`  
`PlayCD` → belongs to one `SongCD`  
`SongCD` → has many `PlayCD`; observes context saves via Combine in `observeContext()`

## Known issues / deliberate decisions

### Release build — Swift optimizer crash (WORKAROUND IN PLACE)
The SIL performance inliner (`isCallerAndCalleeLayoutConstraintsCompatible`) crashes with infinite recursion under whole-module optimization. **Workaround:** `SWIFT_OPTIMIZATION_LEVEL = "-Onone"` is set in the Release build configuration in `project.pbxproj`. This should be revisited after an Xcode update. Do not remove this without verifying archive succeeds.

### Subscription gate
`UsageManager` tracks free-tier limits. `SubscriptionManager` (RevenueCat) tracks pro status. The paywall is shown reactively — the add-session/add-song/add-student save functions do NOT re-check limits at save time (limits are enforced in the UI layer only).

### Audio session arbitration
`AudioManager` is the single gatekeeper for `AVAudioSession`. Clients (`.metronome`, `.tuner`, `.recorder`, `.player`) call `requestSession(for:)` and `releaseSession(for:)`. `requestSession` changes the category on the active session (no `setActive(false)` first — that fails with "busy" while other I/O runs). `releaseSession` always clears ownership, even if deactivation fails. There is **no** timer client and **no** silent audio track — don't reintroduce either (App Review guideline 2.5.4 risk).

### Metronome
`MetronomeEngine` (Views/) schedules clicks on an `AVAudioPlayerNode` at exact sample times with a ~150 ms lookahead, driven from a private serial queue. It is not driven by `Timer`. It restarts itself after `AVAudioEngineConfigurationChange` and interruptions. UI animations follow `engine.beatPulse`, which fires when each click reaches the speaker.

### Session timer + Live Activity
`SessionTimerManager.shared` works from timestamps: elapsed = `accumulated` + time since `segmentStart`. There is no per-second timer and no `@Published` clock string. Views show the clock with `TimelineView(.periodic(from:by: 1))` + `elapsed(at:)`. State persists in UserDefaults (`sessionTimer.*`) and is restored at launch. If the app was killed and not reopened for more than 6 h, the timer is restored paused at the last-active time. The Live Activity (`ClefNotesWidgetsExtension` target, `ClefNotesWidgets/PracticeTimerLiveActivity.swift`) renders `Text(_, style: .timer)`. Its Pause/Resume/Stop `LiveActivityIntent`s call into the app via `TimerIntentBridge`.
- `Clef Notes/Shared/PracticeTimerActivity.swift` is compiled into **both** targets through a `PBXFileSystemSynchronizedBuildFileExceptionSet` in `project.pbxproj`. Put any new shared app/widget file in `Shared/` and add it to that exception set.
- Keep the widget's `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in sync with the app's.

### Practice bar (session tools)
`PracticeSessionManager.shared` (Views/) tracks the session you're in. `SessionDetailViewCD` calls `open(_:)` when it appears, whether or not the session is timed. The manager owns the shared `MetronomeEngine` and the `AudioRecorderManager`, so both keep running across tabs and after their sheets close.
- `PracticeBarView` shows timer, metronome, tuner, record and close controls. On iOS 26.1+ it's the `TabView` bottom accessory (`PracticeBarAccessoryModifier`; `tabViewBottomAccessory(isEnabled:)` needs 26.1). On earlier versions it floats at the bottom of the session screen and the student screen.
- `PracticeSessionChrome` (`.practiceSessionChrome(for:)` on `StudentDetailNavigationView`) presents the metronome/tuner half-height sheets, the paywall, and the recording save sheet, from any tab.
- The session screen is a plain `Form` with a large title. Don't switch its content between sections: swapping the scroll view broke the large title.

### Durations
Model **v4** (current) adds `PracticeSessionCD.durationSeconds`. Always write durations with `setDuration(seconds:)`, which also keeps `durationMinutes` in sync for older app versions and stats. Read them with `totalSeconds`. **Before release:** deploy the CloudKit schema to Production so `durationSeconds` syncs.

## Patterns to follow
- Add/Edit sheets use local `@State` copies of fields, write back to Core Data only in the save action.
- `SaveButtonView` takes an optional `isDisabled:` parameter — always pass it when there's a required field (e.g., non-empty title).
- When creating a new Core Data object before showing a sheet (so the sheet has something to bind to), delete it on cancel if `note.objectID.isTemporaryID` — see `AddNoteSheetCD.swift`.
- Core Data save errors: use `do { try viewContext.save() } catch { print(...) }` — **never** `fatalError` in user-facing save paths.
- `SongCD.observeContext()` Combine sink: always guard `!self.isDeleted, !self.isFault` before accessing managed object properties.

## File layout
```
Clef Notes/
  Core Data/          — NSManagedObject subclasses
  Core Data Views/    — Views that take CD objects as input
  Views/
    Add_Sheets/       — New-object sheets
    Edit_Sheets/      — Edit-object sheets
    StudentDetailContainer/
    StudentSongsTab/
    StatsTab/
    SessionList/
    StudentNotes/
    Awards/
  Main App/           — App/Scene/AppDelegate entry points
  Resources/          — Managers, helpers, shared components
  Theme System/       — AppTheme
  Shared/             — Files compiled into both the app and the widget extension
ClefNotesWidgets/     — Widget extension (practice timer Live Activity)
```

## Session history (what was done in the first big session)

### Bug fixes (PR #5, merged to main)
1. `Persistence.swift` — `privatePersistentStore` / `sharedPersistentStore` made optional; callers in `StudentCD` and `SceneDelegate` updated to guard
2. `DataExporter.swift` — replaced force-unwrap on optional URL with `guard let`
3. `SongCD.swift` — added `!self.isDeleted, !self.isFault` guard in Combine context observer
4. `RecordingMetadataSheetCD.swift` — `onDisappear` now explicitly invalidates timer before nil-ing `audioPlayer`
5. `AddSessionSheetCD.swift` — save button disabled when title is blank; instructor name trimmed before save
6. `AddNoteSheetCD.swift` — Cancel button deletes the note if `objectID.isTemporaryID` (fixes blank notes created on cancel)

### Pre-release cleanup (same PR)
- Deleted `MyPlayground.swift` (scratch file with test data)
- Removed ~20 verbose `print()` calls from `PitchTunerViewModel` including ones inside the per-frame pitch callback
- Removed debug `print()` calls from `SessionDetailViewCD` (subscription status on appear, "Metronome pressed")
- Removed bare `print(url)` / `print(request)` from `MediaCellCD`
- Replaced `fatalError` on Core Data save failure in `SideMenuView`, `AddStudentSheetView`, `AddSongSheetCD`, `StudentSongsTabViewCD`

### Archive fix (main, commit 3aa2e12)
- Added `SWIFT_OPTIMIZATION_LEVEL = "-Onone"` to Release config in `project.pbxproj` to work around Swift compiler inliner crash under WMO
