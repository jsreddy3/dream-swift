# Profile Page Implementation Progress

## Overview
This document tracks the implementation of connecting the Profile page to the backend API, transforming it from mock data to real user insights.

## Archetype Flow (Updated)
1. **New Users**: 
   - Complete onboarding preferences (sleep patterns, dream themes, goals)
   - Backend suggests archetype based on preferences
   - Archetype is saved immediately to user profile
   - Profile page shows archetype without needing dreams
   
2. **Existing Users**:
   - Keep their current archetype (calculated from dreams)
   - No changes to their profile
   
3. **Future Enhancement**:
   - As users record dreams, archetype confidence can be refined
   - Dream content validates or enhances the initial suggestion

## Architecture
- **Backend API**: `/api/users/me/profile` endpoints (already implemented)
- **Models**: `CoreModels/UserProfile.swift` (already defined)
- **Network Layer**: `RemoteProfileStore` (new)
- **View Model**: `ProfileViewModel` (needs update)
- **UI**: `ProfileView` (needs minor updates)

## Implementation Status

### ✅ Step 1: RemoteProfileStore
- [x] Created `Infrastructure/Sources/Infrastructure/RemoteProfileStore.swift`
- [x] Implemented profile fetching methods
- [x] Added preferences API support
- [x] Proper error handling with custom error types
- [x] Snake case conversion for API compatibility

### ✅ Step 2: ProfileViewModel Updates
- [x] Replace mock data with API calls
- [x] Add loading and error states
- [x] Implement profile calculation status polling
- [x] Map backend archetype to frontend enum
- [x] Add refresh capability
- [x] Fixed division by zero in statistics

### ✅ Step 3: ProfileView Updates
- [x] Add loading indicator
- [x] ~~Implement pull-to-refresh~~ (Removed - archetype should be stable)
- [x] Handle empty/pending states
- [x] Show calculation in progress UI
- [x] Updated initialization to accept RemoteProfileStore

### ✅ Step 4: Integration into App
- [x] Created RemoteProfileStore in dreamApp
- [x] Passed through RootView
- [x] Updated MainTabView to accept profileStore
- [x] All components now properly connected

### ✅ Step 5: Build Fixes
- [x] Fixed URL vs String type mismatch in RemoteProfileStore
- [x] Fixed jwt property access (not a function)
- [x] Fixed dictionary encoding for PATCH requests
- [x] All build errors resolved

### ✅ Step 6: Offline Caching
- [x] Created ProfileCache.swift with UserDefaults storage
- [x] Implemented 24-hour cache expiration
- [x] Load cached data immediately for instant display
- [x] Fetch from API in background
- [x] Save successful responses to cache
- [x] Show cached data indicator with age
- [x] Handle offline gracefully with cached data

### ⏳ Step 7: Integration Points
- [ ] Trigger calculation after first dream
- [ ] Add calculation during onboarding
- [ ] Schedule periodic updates

### ⏳ Step 8: Testing
- [ ] Unit tests for RemoteProfileStore
- [ ] Integration tests for full flow
- [ ] Manual testing checklist

## API Contract

### GET /users/me/profile
Response:
```json
{
  "archetype": "starweaver",
  "archetype_confidence": 0.85,
  "statistics": {
    "total_dreams": 15,
    "total_duration_minutes": 120,
    "dream_streak_days": 7,
    "last_dream_date": "2024-01-15"
  },
  "emotional_metrics": [
    {"name": "Joy", "intensity": 0.7, "color": "FFD700"},
    {"name": "Wonder", "intensity": 0.5, "color": "9370DB"}
  ],
  "dream_themes": [
    {"name": "Adventure", "percentage": 40},
    {"name": "Family", "percentage": 30}
  ],
  "recent_symbols": ["🌟", "🌊", "🦋"],
  "last_calculated_at": "2024-01-15T10:30:00Z",
  "calculation_status": "completed"
}
```

### POST /users/me/profile/calculate
Request:
```json
{
  "force_recalculate": true
}
```

Response:
```json
{
  "status": "processing",
  "message": "Profile calculation has been queued"
}
```

## Archetype Mapping

| Backend String | Frontend Enum | Symbol | Description |
|----------------|---------------|--------|-------------|
| starweaver | .starweaver | 🌟 | Symbols and patterns |
| moonwalker | .moonwalker | 🌙 | Journey and adventure |
| soulkeeper | .soulkeeper | 💫 | Emotions and feelings |
| timeseeker | .timeseeker | ⏳ | Past and future |
| shadowmender | .shadowmender | 🌑 | Shadow work |
| lightbringer | .lightbringer | ☀️ | Joy and hope |

## Caching Architecture

### ProfileCache
- **Storage**: UserDefaults with JSON encoding
- **Expiration**: 24 hours from last fetch
- **Version Control**: Cache version tracking to handle model changes
- **Keys**:
  - `com.dreamapp.profile.cached` - Profile data
  - `com.dreamapp.profile.lastFetch` - Timestamp
  - `com.dreamapp.profile.cacheVersion` - Version number

### Cache Flow
1. **On Load**: 
   - Try loading from cache first for instant display
   - Show cached data with age indicator
   - Fetch fresh data in background if cache is expired
2. **On Success**: 
   - Save profile to cache after successful API fetch
   - Clear cache indicators in UI
3. **On Error**: 
   - Keep showing cached data if available
   - Show error indicator without removing profile
   - Fall back to local calculation only if no cache exists

### UI Indicators
- **Cached Data Badge**: Shows when displaying cached data with relative time (e.g., "2 hours ago")
- **Loading State**: Shows during initial load or refresh
- **Calculation Banner**: Shows when profile is being calculated server-side

## Known Issues & Decisions

1. **Polling Strategy**: When calculation_status is "processing", poll every 3 seconds for up to 30 seconds
2. **Error Handling**: Show last cached profile if API fails, with retry option
3. **First Launch**: If no profile exists, show onboarding prompt
4. **Caching**: Store last successful profile in UserDefaults for offline access (24-hour expiration)
5. **No Pull-to-Refresh**: Archetype is meant to be stable and meaningful - users shouldn't be able to refresh it on demand
6. **Cache Invalidation**: Increment cache version when UserProfile model changes to force refresh

## Testing Checklist

- [ ] New user with no dreams sees empty state
- [ ] First dream triggers profile calculation
- [ ] Profile updates after calculation completes
- [ ] Pull to refresh works correctly
- [ ] Error states display properly
- [ ] Offline mode shows cached data
- [ ] Archetype symbols display correctly
- [ ] Emotional waves animate smoothly
- [ ] Statistics calculate correctly
- [ ] Theme percentages add up to 100%

## Next Steps
1. ✅ Build and run the app to test profile page
2. Add profile calculation trigger after dream completion
3. Integrate profile calculation into onboarding flow
4. Add caching for offline support
5. Implement comprehensive error handling

## Current Status
The Profile page is now fully connected to the backend API. When users navigate to the Profile tab:
1. It fetches their profile from the backend
2. If no profile exists or calculation is pending, it triggers calculation
3. Shows loading states and progress indicators
4. Displays real data once available
5. Falls back to local calculation if API fails

## Integration Points

### ✅ 1. During Onboarding (Implemented)
When user completes onboarding:
1. Preferences are saved via `createPreferences()`
2. Archetype is suggested via `suggestArchetype()` 
3. Initial archetype is saved via `saveInitialArchetype()`
4. Profile page immediately shows the archetype

### ⏳ 2. After Dream Completion (Future)
When user records enough dreams, we could:
- Refine the archetype confidence based on dream content
- Potentially suggest archetype changes if patterns strongly differ
- This would be done via `calculateProfile()` with enhanced logic

### ⏳ 3. Periodic Updates (Future)
Could add background updates for:
- Refreshing emotional landscape
- Updating dream themes
- Refining archetype confidence