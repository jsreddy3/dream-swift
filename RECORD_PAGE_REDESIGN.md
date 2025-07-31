# Record Page Redesign Plan

## Vision
Transform the barebones record page into a beautiful, engaging, and intuitive dream recording experience that gives users confidence and peace while capturing their dreams.

## Current State
- Simple "Record a New Dream" title
- Static moon and stars icon
- Voice/Text toggle
- Basic microphone button
- Minimal visual feedback

## Research Findings

### Apple Voice Memos Button
Based on research, Apple does **NOT** provide a built-in Voice Memos-style button component. We need to build this custom:
- GitHub gists exist showing SwiftUI recreations
- Uses shape morphing: `RoundedRectangle` with dynamic corner radius
- Transitions from circle (cornerRadius = width/2) to rounded square (cornerRadius = ~10-15)
- Involves custom animations and state management

## Proposed Improvements

### 1. Custom Voice Memos-Style Record Button
**Implementation Details:**
- Build custom SwiftUI component
- Large button (80-100pt diameter)
- Shape morphing animation:
  - **Idle**: Circle with microphone icon
  - **Recording**: Rounded square with stop icon (square inside circle)
- Ember/orange color scheme
- Simple tap to start/stop (no hold required)
- Haptic feedback on press
- Start/stop audio feedback sounds

**Technical Approach:**
```swift
// Pseudo-code structure
RoundedRectangle(cornerRadius: isRecording ? 15 : width/2)
    .frame(width: size, height: size)
    .foregroundColor(DesignSystem.Colors.ember)
    .overlay(
        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
    )
    .animation(.spring())
```

### 2. Simple Audio Waveform (Option A)
**Design:**
- 5-7 vertical bars showing real-time audio levels
- Smooth animations between level changes
- Ember gradient colors (matching app theme)
- Positioned above the record button

**Technical Implementation:**
- Use `AVAudioRecorder.averagePower(forChannel:)` for audio levels
- Update at 30-60 FPS for smooth animation
- Simple `RoundedRectangle` views with dynamic heights

### 3. Recording State Indicators
**Visual Feedback:**
- Recording timer (MM:SS format)
- Pulsing red dot indicator
- Subtle background gradient shift when recording
- Clear visual confirmation of ongoing recording

**Audio Feedback:**
- Start recording sound (gentle chime)
- Stop recording sound (soft completion tone)
- Use system sounds or custom audio files

### 4. Smart Auto-Save Strategy
**Implementation Approach:**
- **Continuous Recording**: Keep one continuous audio file
- **Progressive Enhancement Strategy**:
  - Short recordings (<30s): Behave exactly like current system (no overhead)
  - Long recordings (≥30s): Enable checkpoint system
  - Ensures 10-second dreams remain fast with no added latency
- **Checkpoint System**: 
  - Only activate after 30 seconds of recording
  - Save metadata checkpoints every 30 seconds thereafter
  - Mark file as "in progress" in database
  - Update duration and last checkpoint time
- **Parallel Processing**:
  - Queue segments for transcription as recorded
  - Stitch transcriptions together in order
  - Maintain segment order with timestamps
- **Recovery**:
  - If app crashes, can resume from last checkpoint
  - Show "Recovering previous recording..." on restart

**Critical Requirements:**
- Short dreams (10-30s) must have zero added latency
- User can record 5-10+ minutes continuously
- Full transcript available after stopping
- No interruption to recording flow
- Seamless experience even with background saves

### 5. Enhanced UI Layout
**Top Section:**
- Contextual greeting based on time of day
- Subtle animated background (stars twinkling)

**Middle Section:**
- Waveform visualization (5-7 bars)
- Recording timer
- Status text ("Recording...", "Tap to start")

**Bottom Section:**
- Large record button (center)
- Voice/Text toggle (refined design)

## Technical Architecture

### Audio Recording Stack
```
AVAudioSession (manages audio session)
    ↓
AVAudioRecorder (handles recording)
    ↓
Audio File (continuous .m4a file)
    ↓
Checkpoint System (metadata saves)
    ↓
Transcription Queue (parallel processing)
```

### State Management
- Single source of truth in ViewModel
- Published properties for UI updates
- Combine framework for reactive updates

## Implementation Plan

### Phase 1: Custom Record Button
**Tasks:**
1. Research existing implementations
2. Create RecordButton component
3. Implement circle-to-square morphing
4. Add spring animations
5. Integrate haptic feedback
6. Add VoiceOver labels

**Success Criteria:**
- Button morphs smoothly between states in < 0.1s
- Haptic feedback fires reliably on all devices
- VoiceOver announces "Start recording" / "Stop recording" correctly
- No visual glitches across iPhone SE to Pro Max sizes

**Feature Flag:** `recordPageRedesign.customButton`

### Phase 2: Audio Infrastructure ✅ IMPLEMENTED
**Tasks:**
1. ✅ Set up AVAudioSession properly (44.1kHz, high quality)
2. ✅ Implement continuous recording with AudioRecorderActor
3. ✅ Add checkpoint system (saves every 30s for long recordings)
4. ✅ Create recovery mechanism (checkpoint metadata saved)
5. ✅ Configure background mode permissions (Info.plist updated)

**Implementation Details:**
- ✅ Created ContinuousAudioRecorder with progressive enhancement
- ✅ Short recordings (<30s) use simple path with zero overhead
- ✅ Long recordings (≥30s) activate checkpoint system
- ✅ Feature flag controls which recorder is used
- ✅ Checkpoint metadata saved alongside audio files
- ✅ Background audio mode enabled in Info.plist

**Success Criteria:**
- Short recordings (<30s) have identical performance to current system
- Record 10+ minutes ≥ 5 times without audio glitches
- Average memory usage < 150MB during recording
- Background recording works with screen locked
- Recovery succeeds after force-quit in < 3 seconds
- Checkpoint saves complete in < 100ms

**Info.plist Requirements:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

**Feature Flag:** `recordPageRedesign.continuousRecording`

### Phase 3: Simple Waveform Visualization
**Tasks:**
1. Set up audio level monitoring
2. Create 5-7 bar visualization with `debugDataSource`
3. Implement smooth animations
4. Style with ember gradients
5. Add unit test hooks

**Success Criteria:**
- Waveform updates at 30+ FPS on iPhone XR
- CPU usage < 10% when visualizing
- Graceful degradation if audio levels unavailable
- Unit tests can inject deterministic levels

**Feature Flag:** `recordPageRedesign.waveformViz`

### Phase 4: State Management & UI
**Tasks:**
1. Add recording timer
2. Implement status indicators
3. Add start/stop sounds with toggle in Settings
4. Create polished layout
5. Ensure VoiceOver compatibility

**Success Criteria:**
- Timer accuracy within 0.1s over 10 minutes
- All states announced properly by VoiceOver
- Audio feedback can be disabled via Settings
- Layout works on all device sizes without clipping

**Feature Flag:** `recordPageRedesign.fullUI`

### Phase 5: Testing & Polish
**Tasks:**
1. Test long recordings (10+ minutes)
2. Test interruption recovery
3. Verify transcription stitching
4. Performance optimization
5. Battery usage testing
6. Implement storage cleanup policy

**Success Criteria:**
- 10-minute recording uses < 5% battery on iPhone 12
- Transcription stitching maintains < 50ms gaps
- Storage auto-cleanup after 30 days or 1GB limit
- All interruption scenarios recover gracefully
- Memory leaks: 0 detected in Instruments

## Critical Testing Scenarios
1. **Long Recording**: 10-minute continuous recording
2. **Interruptions**: Phone calls, notifications
3. **Background**: App backgrounding during recording
4. **Recovery**: Force quit and recovery
5. **Memory**: Monitor memory usage during long recordings

## Implementation Notes

### Button Animation
- Use `withAnimation(.easeInOut(duration: 0.08))` for < 0.1s transitions
- Corner radius: size/2 (circle) → 15 (rounded square)
- Scale effect: 0.95 on press for tactile feedback
- Disable animation interruption during morph

### Audio Format
```swift
let settings = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 44100,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
```

### Waveform Update Loop
- Timer firing at 30-60 Hz
- Read `averagePower(forChannel: 0)`
- Normalize to 0-1 range
- Animate bar heights

## Questions Resolved
1. **Waveform**: Simple bars (Option A) ✓
2. **Stop mechanism**: Simple tap (like Voice Memos) ✓
3. **Auto-save**: Checkpoint system with continuous recording ✓
4. **Button component**: Custom build required ✓
5. **Audio feedback**: Yes, start/stop sounds ✓

## Next Steps
1. Begin Phase 1 with custom button component
2. Set up proper audio permissions handling
3. Create checkpoint system architecture
4. Build and test incrementally