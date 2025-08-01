# Dream Image Generation Feature Specification

## Vision
Transform the abstract, ethereal nature of dreams into stunning visual art that captures the essence, emotion, and narrative of each user's dream. This feature will create a moment of magic where users see their subconscious made visible.

## Core Experience

### The Magic Moment
1. User taps "Visualize" button (appears after interpretation loads)
2. Screen subtly dims, particles begin floating upward
3. "Painting your dreamscape..." message appears with mystical animation
4. Gradual reveal: image materializes from particles/mist (3-5 seconds)
5. Full image appears with subtle glow effect
6. User can tap to view fullscreen with Ken Burns effect

### Design Principles
- **Anticipation**: Build excitement during generation
- **Delight**: The reveal should feel magical, not mechanical
- **Persistence**: Images become part of the dream's permanent record
- **Shareability**: Users will want to share these dreamscapes

## User Journey

### 1. Discovery
- "Visualize" button appears next to "Interpret" after dream is processed
- Subtle shimmer animation draws attention
- First-time tooltip: "Transform your dream into art ✨"

### 2. Generation
- Tap triggers immediate haptic feedback
- Button morphs into progress indicator
- Background particles/stars begin animated movement
- Status messages cycle through poetic phrases:
  - "Weaving dreamscape threads..."
  - "Painting subconscious colors..."
  - "Crystallizing ethereal visions..."

### 3. Reveal
- Image fades in from center outward
- Subtle parallax effect on first view
- Glow effect around edges
- Auto-saves to dream record

### 4. Interaction
- Tap image for fullscreen view
- Pinch to zoom
- Long press for options:
  - Save to Photos
  - Share
  - Regenerate
  - View prompt

### 5. Persistence
- Thumbnail in dream library
- Full image in dream detail
- Included in exports
- Synced across devices

## Technical Architecture

### Image Generation Pipeline

```
User Taps Visualize
    ↓
Prompt Generation (on-device)
    ↓
API Request to Backend
    ↓
Backend Queues Job
    ↓
Generation Service (DALL-E 3 / Stable Diffusion XL)
    ↓
Image Optimization
    ↓
CDN Upload
    ↓
Push Update to Client
    ↓
Local Cache & Display
```

### Model Selection

**Recommended: DALL-E 3**
- Highest quality and consistency
- Best prompt adherence
- 1024x1024 or 1792x1024 resolution
- ~$0.04-0.08 per image
- 5-20 second generation time

**Alternative: Stable Diffusion XL**
- Open source, more control
- Can run on our infrastructure
- Custom fine-tuning possible
- ~$0.01-0.02 per image
- 10-30 second generation time

### Prompt Engineering

**Base Prompt Structure:**
```
Create a [style_modifier] artistic visualization of this dream: [dream_summary]. 
Emphasize [primary_emotion] mood with [dominant_symbols] as key elements. 
Style: [artistic_style]. 
Lighting: [time_of_day] with [lighting_mood].
Color palette: [extracted_colors].
Composition: [scene_type].
```

**Dynamic Elements Extracted:**
1. **Style Modifier**: Based on dream archetype
   - Starweaver → "ethereal, cosmic"
   - Heartkeeper → "warm, intimate"
   - etc.

2. **Dream Summary**: AI-condensed version (max 100 words)

3. **Primary Emotion**: From emotional analysis

4. **Dominant Symbols**: Top 3-5 symbols/themes

5. **Artistic Style**: User preference or auto-selected:
   - Surrealist painting
   - Ethereal photography  
   - Mystical illustration
   - Dreamlike watercolor

6. **Lighting & Time**: Extracted from dream content

7. **Color Palette**: Based on emotional tone

**Example Generated Prompt:**
```
Create an ethereal, cosmic artistic visualization of this dream: A vast library 
with books floating like birds, transforming into butterflies as they reach 
towering windows opening to stars. Emphasize wonder and transformation with 
books, butterflies, and stars as key elements. Style: Surrealist painting 
with photographic details. Lighting: Twilight with bioluminescent glow. 
Color palette: Deep purples, gold highlights, cosmic blues. 
Composition: Interior space opening to infinite exterior.
```

### Storage Architecture

```
Local Device:
- Thumbnail (256x256) - immediate display
- Full image (1024x1024) - cached on view
- Metadata (prompt, settings, timestamp)

Cloud Storage:
- Original (highest res)
- Web-optimized version
- Thumbnail
- Generation metadata
- CDN distribution

Database:
- Image URLs
- Generation parameters
- User preferences
- Usage analytics
```

## Implementation Phases

### Phase 1: Backend API Integration

#### Step 1.1: DALL-E 3 API Integration
**Implementation**:
- Add OpenAI SDK to backend dependencies
- Create `ImageGenerationService` with single method
- Hardcode test prompt: "A surreal dreamscape with floating books"

**Success Metrics**:
- ✓ API call returns image URL
- ✓ Response time < 20 seconds
- ✓ Image URL is valid and accessible

**Debugging**:
- Log full API request/response
- Check API key validity
- Verify account has credits
- Test with curl first

**Testing**:
```bash
# Quick test
curl -X POST localhost:8000/api/test-image-gen
# Should return: {"url": "https://...", "time": 15.2}
```

#### Step 1.2: Database Schema Update
**Implementation**:
- Add to Dream model: `image_url`, `image_prompt`, `image_generated_at`
- Run migration
- Update Dream API serializer

**Success Metrics**:
- ✓ Migration runs without errors
- ✓ Can save/retrieve image URLs
- ✓ API returns new fields

**Debugging**:
- Check migration SQL
- Verify column types
- Test with direct DB query

**Testing**:
```python
# In Django shell
dream = Dream.objects.first()
dream.image_url = "test.jpg"
dream.save()
assert dream.image_url == "test.jpg"
```

#### Step 1.3: S3 Upload Pipeline**Implementation**:
- Configure S3 bucket with public read
- Add boto3, implement upload method
- Generate unique paths: `dreams/{user_id}/{dream_id}/{uuid}.jpg`

**Success Metrics**:
- ✓ Image downloads from DALL-E
- ✓ Uploads to S3 in < 2 seconds
- ✓ Returns CDN URL

**Debugging**:
- Check S3 permissions
- Verify image bytes are valid
- Log upload progress
- Test with small test image first

**Testing**:
```python
# Test upload
test_image = requests.get("https://picsum.photos/1024")
url = upload_to_s3(test_image.content, "test/path.jpg")
assert requests.get(url).status_code == 200
```

#### Step 1.4: API Endpoint**Implementation**:
- Create POST `/api/dreams/{id}/generate-image`
- Check dream ownership
- Call generation service
- Return URL or job ID

**Success Metrics**:
- ✓ Endpoint requires auth
- ✓ Returns 200 with URL
- ✓ Updates dream record
- ✓ Handles errors gracefully

**Debugging**:
- Test with Postman/curl
- Check auth headers
- Verify dream ID exists
- Log all steps

**Testing**:
```bash
# Full integration test
TOKEN="your-auth-token"
DREAM_ID="test-dream-id"
curl -X POST -H "Authorization: Bearer $TOKEN" \
  localhost:8000/api/dreams/$DREAM_ID/generate-image
```

### Phase 2: Prompt Engineering
#### Step 2.1: Basic Prompt Generator**Implementation**:
- Create `DreamPromptGenerator` class
- Extract: dream text (first 500 chars) + emotion + time of day
- Template: "Dreamlike artistic visualization of: {summary}. Mood: {emotion}. Time: {time}."

**Success Metrics**:
- ✓ Generates prompt < 300 chars
- ✓ Includes key dream elements
- ✓ No sensitive content exposed

**Debugging**:
- Print prompt before sending
- Check for null values
- Validate prompt length
- Test with edge cases (empty dreams)

**Testing**:
```python
dream = {"text": "Flying over ocean", "emotion": "peaceful", "time": "night"}
prompt = generator.generate(dream)
assert "ocean" in prompt
assert "peaceful" in prompt
assert len(prompt) < 300
```

#### Step 2.2: Symbol Extraction**Implementation**:
- Parse interpretation for symbols/themes
- Extract top 3-5 symbols
- Add to prompt: "Key elements: {symbols}"

**Success Metrics**:
- ✓ Extracts 3-5 symbols per dream
- ✓ Symbols are relevant
- ✓ Handles missing interpretation

**Debugging**:
- Log extracted symbols
- Check interpretation format
- Handle JSON parsing errors
- Fallback to empty list

**Testing**:
```python
interpretation = {"symbols": ["water", "flight", "freedom"]}
symbols = extract_symbols(interpretation)
assert len(symbols) <= 5
assert "water" in symbols
```

#### Step 2.3: Style System**Implementation**:
- Map dream archetypes to art styles
- Add style suffix to prompt
- Default style: "surreal digital art"

**Success Metrics**:
- ✓ Each archetype has unique style
- ✓ Style enhances dream mood
- ✓ Fallback style works

**Debugging**:
- Log archetype → style mapping
- Test all archetype values
- Verify style in final prompt

**Testing**:
```python
styles = {
    "Starweaver": "cosmic ethereal art",
    "Heartkeeper": "warm impressionist painting"
}
assert get_style("Starweaver") == "cosmic ethereal art"
assert get_style("Unknown") == "surreal digital art"  # fallback
```

#### Step 2.4: Safety Filters**Implementation**:
- Keyword blocklist for inappropriate content
- Remove personal names/locations
- Add "artistic, non-explicit" to all prompts

**Success Metrics**:
- ✓ Filters explicit keywords
- ✓ Removes PII
- ✓ Doesn't over-filter

**Debugging**:
- Log filtered vs original
- Test with edge cases
- Check filter isn't too aggressive

**Testing**:
```python
unsafe = "Dream about John Smith at 123 Main St"
safe = filter_prompt(unsafe)
assert "John Smith" not in safe
assert "123 Main St" not in safe
```

### Phase 3: iOS UI Implementation
#### Step 3.1: Add Visualize Button**Implementation**:
- Add button next to "Interpret" in DreamEntryView
- Show only when interpretation exists
- Glowing ember animation when available

**Success Metrics**:
- ✓ Button appears conditionally
- ✓ Tap registers immediately
- ✓ Animation runs at 60fps

**Debugging**:
- Check interpretation state
- Log button taps
- Profile animation performance
- Test on slow devices

**Testing**:
```swift
// UI Test
app.buttons["Visualize"].tap()
XCTAssert(app.activityIndicators.count == 1)
```

#### Step 3.2: Generation Loading State**Implementation**:
- Create `ImageGenerationView` overlay
- Particle system (reuse from ProfileView)
- Cycling status messages
- Progress indicator

**Success Metrics**:
- ✓ Overlay appears immediately
- ✓ Particles animate smoothly
- ✓ Messages cycle every 3s
- ✓ Can cancel generation

**Debugging**:
- FPS counter in debug mode
- Log state transitions
- Memory profiler for particles
- Test interruption handling

**Testing**:
```swift
// Check loading state
viewModel.startGeneration()
XCTAssert(viewModel.isGenerating)
XCTAssert(viewModel.statusMessage != nil)
```

#### Step 3.3: Image Reveal Animation**Implementation**:
- Fade from particles to image
- Scale from 0.8 to 1.0
- Glow effect around edges
- Haptic feedback on complete

**Success Metrics**:
- ✓ Smooth transition (no flicker)
- ✓ Animation completes in 1.5s
- ✓ Haptic fires on time
- ✓ Image fully loaded before reveal

**Debugging**:
- Log animation stages
- Check image download completion
- Verify haptic availability
- Test with slow network

**Testing**:
```swift
// Animation test
let expectation = XCTestExpectation()
viewModel.revealImage {
    XCTAssert(viewModel.generatedImage != nil)
    expectation.fulfill()
}
wait(for: [expectation], timeout: 2.0)
```

#### Step 3.4: Error Handling UI**Implementation**:
- Error states: network, API limit, generation failed
- Retry button with backoff
- User-friendly error messages
- Fall back to interpret view

**Success Metrics**:
- ✓ Each error has unique message
- ✓ Retry works correctly
- ✓ No crash on errors
- ✓ Can dismiss error state

**Debugging**:
- Force each error type
- Log error transitions
- Test retry logic
- Verify cleanup on dismiss

**Testing**:
```swift
// Error handling
viewModel.simulateError(.networkError)
XCTAssert(viewModel.errorMessage.contains("connection"))
XCTAssert(app.buttons["Retry"].exists)
```

#### Step 3.5: Image Display in Dream**Implementation**:
- Add image section to DreamEntryView
- Lazy loading with placeholder
- Tap for fullscreen
- Cache in ImageCache

**Success Metrics**:
- ✓ Image loads within 1s
- ✓ Placeholder shows immediately
- ✓ Cached images instant
- ✓ Memory stays under 100MB

**Debugging**:
- Log cache hits/misses
- Monitor memory usage
- Check image dimensions
- Test cache eviction

**Testing**:
```swift
// Cache test
let image1 = cache.image(for: dreamId)
XCTAssertNil(image1)
cache.store(testImage, for: dreamId)
let image2 = cache.image(for: dreamId)
XCTAssertNotNil(image2)
```

### Phase 4: Image Viewer & Polish
#### Step 4.1: Fullscreen Viewer**Implementation**:
- Create `DreamImageViewer` modal
- Pinch to zoom (2x-5x)
- Double tap to zoom
- Pan when zoomed
- Dismiss gesture

**Success Metrics**:
- ✓ Gestures feel natural
- ✓ Zoom is smooth (60fps)
- ✓ Bounds limiting works
- ✓ Dismiss animation clean

**Debugging**:
- Log gesture recognizer states
- Check transform matrices
- Monitor fps during zoom
- Test gesture conflicts

**Testing**:
```swift
// Zoom test
viewer.pinchToZoom(scale: 2.0)
XCTAssert(viewer.currentScale == 2.0)
viewer.pinchToZoom(scale: 10.0)
XCTAssert(viewer.currentScale == 5.0) // max limit
```

#### Step 4.2: Sharing Integration**Implementation**:
- Long press → Share menu
- Include dream title + date
- Share image + link to dream
- Activity indicator during prep

**Success Metrics**:
- ✓ Share sheet appears < 0.5s
- ✓ Image quality preserved
- ✓ All share targets work
- ✓ Includes metadata

**Debugging**:
- Check image format
- Verify share items
- Test with various apps
- Log share completion

**Testing**:
```swift
// Share test
let items = viewModel.prepareShareItems()
XCTAssert(items.count == 2) // image + text
XCTAssert(items[0] is UIImage)
XCTAssert(items[1] is String)
```

#### Step 4.3: Library Integration**Implementation**:
- Show image badge on dream cards
- Lazy load thumbnails
- Gradient overlay for text readability
- Loading shimmer effect

**Success Metrics**:
- ✓ Thumbnails load smoothly
- ✓ No scroll jank
- ✓ Badges appear correctly
- ✓ Text remains readable

**Debugging**:
- Profile scroll performance
- Check image sizing
- Monitor concurrent loads
- Test with 100+ dreams

**Testing**:
```swift
// Library performance
let scrollTest = measureMetrics([.scrollingFPS]) {
    libraryView.scrollToBottom()
}
XCTAssert(scrollTest.fps > 55)
```

#### Step 4.4: Regeneration Flow**Implementation**:
- "Generate New" button in viewer
- Confirm dialog for cost awareness
- Keep history of previous images
- Swipe between versions

**Success Metrics**:
- ✓ Regeneration works reliably
- ✓ History preserved
- ✓ Can view all versions
- ✓ Clear cost messaging

**Debugging**:
- Track generation count
- Verify history storage
- Test version switching
- Check rate limiting

**Testing**:
```swift
// Regeneration test
let originalImage = dream.currentImage
viewModel.regenerateImage()
wait(2.0)
XCTAssert(dream.imageHistory.count == 2)
XCTAssert(dream.currentImage != originalImage)
```

### Phase 5: Production Readiness
#### Step 5.1: Rate Limiting**Implementation**:
- Backend: 10 images per day per user
- iOS: Show remaining count
- Reset at midnight UTC
- Premium override flag

**Success Metrics**:
- ✓ Limits enforced accurately
- ✓ Clear user messaging
- ✓ Resets work correctly
- ✓ Premium bypass works

**Debugging**:
- Log limit checks
- Test timezone handling
- Verify Redis counters
- Check premium flags

**Testing**:
```python
# Rate limit test
for i in range(11):
    response = generate_image(user_id)
    if i < 10:
        assert response.status_code == 200
    else:
        assert response.status_code == 429
```

#### Step 5.2: Analytics**Implementation**:
- Track: generation started/completed/failed
- Time to generate
- Error types
- Sharing events

**Success Metrics**:
- ✓ All events fire correctly
- ✓ No PII in analytics
- ✓ Can build funnel
- ✓ Error tracking works

**Debugging**:
- Use analytics debug mode
- Verify event properties
- Check batch sending
- Test offline queuing

**Testing**:
```swift
// Analytics test
Analytics.testMode = true
viewModel.generateImage()
XCTAssert(Analytics.events.contains("image_generation_started"))
```

#### Step 5.3: Performance Optimization**Implementation**:
- Preload image during generation
- Progressive JPEG loading
- Thumbnail generation on backend
- Memory cache tuning

**Success Metrics**:
- ✓ Image appears instantly after generation
- ✓ Memory < 150MB with 10 images
- ✓ No scroll jank in library
- ✓ Background loading works

**Debugging**:
- Instrument memory usage
- Log loading stages
- Profile main thread
- Test memory warnings

**Testing**:
```swift
// Memory test
autoreleasepool {
    for _ in 0..<20 {
        cache.store(largeImage, for: UUID().uuidString)
    }
}
XCTAssert(memoryUsage() < 150_000_000) // 150MB
```

## Debug Tooling Setup

### Backend Debug Endpoints
```python
# Add to urls.py in DEBUG mode
/api/debug/image-gen-test  # Test with fixed prompt
/api/debug/clear-rate-limit  # Reset rate limits
/api/debug/force-error/{type}  # Force specific errors
```

### iOS Debug Menu
```swift
#if DEBUG
- Force regeneration
- Clear image cache  
- Show generation logs
- Simulate slow network
- Memory usage graph
#endif
```

### Monitoring Dashboard
- Generation success rate
- Average generation time
- Error types breakdown
- Cost per user
- API quota remaining

## Cost Projections

### Per User Estimates (Monthly)
- Average user: 10 dreams → 10 images
- Power user: 30 dreams → 30 images
- Cost per image: $0.04 (DALL-E 3)
- Storage per image: $0.001

### Scaling Considerations
- 1,000 users: $400-1,200/month
- 10,000 users: $4,000-12,000/month
- Consider usage limits or premium tier

## Monetization Options

### Freemium Model
- Free: 5 images/month
- Premium: Unlimited + styles + variations
- Pro: Batch generation + API access

### Feature Unlocks
- Basic style: Free
- Premium styles: Subscription
- Variations: Premium only
- High-res downloads: Premium

## Overall Success Metrics

### Technical Health Metrics
**Real-time Monitoring**:
- API success rate > 95%
- Generation time p50 < 15s, p95 < 25s
- iOS crash rate < 0.1%
- Memory usage p95 < 150MB
- Image load time p50 < 500ms

**Debugging Signals**:
- Error type distribution
- Retry attempt patterns
- Cache hit rate > 80%
- Network timeout frequency
- Memory warning events

### User Experience Metrics
**Engagement Tracking**:
- % users who try feature in first session: target 60%
- % dreams with images after 30 days: target 40%
- Average time viewing image: target > 10s
- Share rate: target 15% of generated images
- Regeneration rate: < 20% (quality indicator)

**Quality Indicators**:
- Time from tap to image reveal: < 20s
- User-reported quality issues: < 5%
- Support tickets per 1000 generations: < 10
- 1-tap sharing success rate: > 90%

### Business Metrics
**Cost Management**:
- Cost per user per month: < $0.50
- API error waste: < 2% of calls
- Cache efficiency: > 80% hit rate
- S3 storage growth: linear with users

**Growth Indicators**:
- Feature adoption week-over-week
- Premium conversion from image users
- Viral coefficient from shares
- Retention impact (cohort analysis)

## Step-by-Step Validation Checkpoints

### After Each Implementation Step:
1. **Functional Test**: Does the feature work as intended?
2. **Performance Test**: Does it meet speed/memory targets?
3. **Error Test**: Do all error cases handle gracefully?
4. **Integration Test**: Does it work with existing features?
5. **User Test**: Can a new user understand and use it?

### Debug Checklist for Common Issues:

**"Image generation is slow"**:
1. Check API response time in logs
2. Verify S3 upload speed
3. Profile image download on client
4. Check for main thread blocking
5. Verify CDN is being used

**"Images don't appear"**:
1. Check API key validity
2. Verify network connectivity
3. Check image URL in response
4. Test URL directly in browser
5. Check cache corruption
6. Verify auth token

**"App crashes during generation"**:
1. Check memory usage
2. Profile for retain cycles
3. Verify error handling
4. Check for force unwraps
5. Test with memory pressure

**"Wrong image for dream"**:
1. Log generated prompt
2. Check dream ID mapping
3. Verify cache key uniqueness
4. Check for race conditions
5. Validate prompt generation logic

## Risk Mitigation

### Technical Risks
1. **API Failures**: Implement retry logic, fallback providers
2. **Long Generation Times**: Show progress, allow background generation
3. **Poor Quality Results**: A/B test prompts, allow regeneration
4. **Storage Costs**: Implement lifecycle policies, compression

### Product Risks
1. **Inappropriate Content**: Robust safety filters, moderation
2. **Unmet Expectations**: Set clear expectations, iterate on prompts
3. **Feature Overuse**: Implement sensible limits, education
4. **Privacy Concerns**: Clear data policies, on-device options

### Business Risks
1. **Runaway Costs**: Hard limits, monitoring, alerts
2. **API Deprecation**: Multiple provider support
3. **Competition**: Focus on integration, not just generation

## Future Enhancements

### V2 Possibilities
- Dream sequence animations
- AR dream viewing
- Collaborative dreamscapes
- Custom model training
- Dream art NFTs
- Physical print ordering
- Dream journal covers
- Social dream galleries

### Integration Ideas
- Apple Photos Memories
- Instagram Stories
- Therapy session materials
- Desktop wallpapers
- Apple Watch faces

## Privacy & Ethics

### Data Handling
- Images processed on secure servers
- No human review of generated images
- Auto-deletion options
- Export includes all images
- Clear consent for each generation

### Content Guidelines
- No explicit content generation
- Cultural sensitivity in prompts
- Age-appropriate results
- Therapeutic use considerations

## Launch Strategy

### Soft Launch (Week 4)
1. Enable for 10% of users
2. Monitor metrics closely
3. Gather feedback
4. Iterate on prompts

### Full Launch (Week 6)
1. Press release about feature
2. In-app announcement
3. Social media campaign
4. Influencer partnerships

### Post-Launch (Ongoing)
1. Weekly prompt optimization
2. New style releases
3. Community showcases
4. Feature improvements

## Questions to Resolve

1. **Pricing Model**: Freemium limits vs pure premium feature?
2. **Style Options**: Curated list vs AI-detected best match?
3. **Regeneration**: Unlimited vs limited attempts?
4. **Resolution**: Standard 1024x1024 vs options?
5. **Batch Processing**: Auto-generate for past dreams?
6. **Social Features**: Public gallery or keep private?

## Development Checklist

### Pre-Development
- [ ] Finalize API provider (DALL-E 3 vs SDXL)
- [ ] Set up API accounts and billing
- [ ] Design mockups for all states
- [ ] Create animation prototypes
- [ ] Define prompt templates

### Infrastructure
- [ ] API integration setup
- [ ] S3 bucket configuration
- [ ] CDN setup
- [ ] Database schema updates
- [ ] Monitoring dashboard

### Backend
- [ ] Image generation service
- [ ] Prompt generation logic
- [ ] Queue management
- [ ] Storage pipeline
- [ ] API endpoints

### iOS
- [ ] UI components
- [ ] Animation system
- [ ] Image caching
- [ ] Offline support
- [ ] Error handling

### Testing
- [ ] Unit test suite
- [ ] Integration tests
- [ ] UI automation tests
- [ ] Performance tests
- [ ] Beta testing group

### Launch
- [ ] Feature flags configured
- [ ] Analytics tracking
- [ ] Documentation
- [ ] Support materials
- [ ] Marketing assets

## Conclusion

This feature has the potential to be the most shareable, delightful aspect of the Dream app. By focusing on the magical reveal moment and ensuring consistent, high-quality results, we can create something that users will genuinely love and share with others. The phased approach allows us to validate core assumptions early while building toward a comprehensive feature that enhances the dream journaling experience.

The key to success will be:
1. Nailing the prompt generation to create relevant, beautiful images
2. Making the generation process feel magical, not mechanical
3. Ensuring reliability at scale
4. Keeping costs manageable
5. Maintaining user privacy and trust

With careful execution, this could become the defining feature that sets Dream apart from any other dream journaling app.