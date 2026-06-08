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
`AudioManager` is the single gatekeeper for `AVAudioSession`. Clients (`.timer`, `.metronome`, `.tuner`, `.recorder`, `.player`) call `requestSession(for:)` and `releaseSession(for:)`. Only one client is active at a time. The timer uses a silent audio file to keep the session alive in the background.

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
