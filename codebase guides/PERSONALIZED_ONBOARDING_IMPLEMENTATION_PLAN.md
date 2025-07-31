# Personalized Onboarding Implementation Plan

## Overview
This document outlines the step-by-step implementation of personalized onboarding features for the Dream app. Each feature will be fully implemented, debugged, and tested before moving to the next.

## Implementation Order & Roadmap

### Phase 1: Foundation (Database & API)
**Goal**: Set up the backend infrastructure for storing user preferences

#### Step 1.1: Create User Preferences Model
- [x] Create database migration for `user_preferences` table
- [x] Create SQLAlchemy model
- [x] Create Pydantic schemas for API
- [x] Add repository methods

**Testing Checkpoint**:
- [x] Migration runs successfully
- [x] Can create/read/update preferences via repository
- [ ] API endpoints return correct data

#### Step 1.2: Create Preferences API Endpoints
- [x] POST `/users/me/preferences` - Create/update preferences
- [x] GET `/users/me/preferences` - Get current preferences
- [x] PATCH `/users/me/preferences` - Partial updates
- [x] POST `/users/me/preferences/suggest-archetype` - Suggest archetype

**Testing Checkpoint**:
- [x] Test with Postman/curl
- [x] Verify JWT authentication works
- [x] Check data persistence

### Phase 2: Enhanced Onboarding Flow (iOS)
**Goal**: Collect user data during onboarding

#### Step 2.1: Create Data Models
- [x] Create Swift models for preferences
- [x] Create enums for options (SleepQuality, DreamGoal, etc.)
- [x] Add to CoreModels package

**Testing Checkpoint**:
- [x] Models compile
- [x] Can encode/decode to JSON
- [x] Match backend schema

#### Step 2.2: Build Onboarding Data Collection Screens
- [x] Sleep Pattern Screen (bedtime, wake time, quality)
- [x] Dream Recall Screen (frequency, vividness)
- [x] Dream Themes Screen (common themes selection)
- [x] Goals & Interests Screen (primary goal, interests)
- [x] Notification Preferences Screen

**Testing Checkpoint**:
- [x] Each screen renders correctly
- [x] Data binding works
- [x] Navigation between screens works
- [x] State persists during navigation

#### Step 2.3: Integrate with Backend
- [x] Create API client methods for preferences
- [x] Save preferences at end of onboarding
- [x] Handle errors gracefully

**Testing Checkpoint**:
- [x] Preferences save to backend
- [x] Can retrieve saved preferences
- [x] Error handling works (network issues, etc.)

### Phase 3: Smart Dream Reminders
**Goal**: Send personalized notifications based on user preferences

#### Step 3.1: Local Notifications (iOS)
- [ ] Request notification permissions during onboarding
- [ ] Schedule notifications based on reminder_time
- [ ] Create personalized notification content

**Testing Checkpoint**:
- [ ] Permissions request works
- [ ] Notifications appear at correct time
- [ ] Content is personalized

#### Step 3.2: Backend Notification Service
- [ ] Create notification scheduler service
- [ ] Add push notification infrastructure
- [ ] Create notification templates by user type

**Testing Checkpoint**:
- [ ] Scheduler runs at correct intervals
- [ ] Notifications sent to correct users
- [ ] Templates render correctly

### Phase 4: Tailored AI Analysis
**Goal**: Customize AI prompts based on user goals

#### Step 4.1: Update AI Prompt Generation
- [ ] Modify dream analysis service to use preferences
- [ ] Create goal-specific prompt templates
- [ ] Add interest-based analysis focus

**Testing Checkpoint**:
- [ ] Different goals produce different analyses
- [ ] AI responses align with user interests
- [ ] Quality of analysis improves

#### Step 4.2: Update Interpretation Questions
- [ ] Generate questions based on user goals
- [ ] Customize question types by interest
- [ ] Add goal-specific follow-ups

**Testing Checkpoint**:
- [ ] Questions match user profile
- [ ] More relevant to stated interests
- [ ] User engagement metrics improve

### Phase 5: Initial Archetype Assignment
**Goal**: Assign archetype during onboarding

#### Step 5.1: Archetype Suggestion Algorithm
- [ ] Create algorithm based on preferences
- [ ] Map goals/themes to archetypes
- [ ] Add confidence scoring

**Testing Checkpoint**:
- [ ] Algorithm returns reasonable archetypes
- [ ] Confidence scores make sense
- [ ] Can override with user choice

#### Step 5.2: Show Personalized Welcome
- [ ] Create personalized welcome screen
- [ ] Show suggested archetype
- [ ] Display customized first message

**Testing Checkpoint**:
- [ ] Welcome screen shows correct archetype
- [ ] Message matches user preferences
- [ ] Smooth transition to main app

### Phase 6: Dream Recall Enhancement
**Goal**: Help users who rarely remember dreams

#### Step 6.1: Recall-Specific Features
- [ ] Add pre-sleep intention setting
- [ ] Create morning quick-capture mode
- [ ] Build recall tips system

**Testing Checkpoint**:
- [ ] Features appear for low-recall users
- [ ] Quick capture is faster
- [ ] Tips are helpful and relevant

#### Step 6.2: Progress Tracking
- [ ] Track recall improvement
- [ ] Create progress visualizations
- [ ] Add encouragement messages

**Testing Checkpoint**:
- [ ] Progress tracked accurately
- [ ] Visualizations update correctly
- [ ] Messages appear at right times

### Phase 7: Theme-Based Features
**Goal**: Organize content by user interests

#### Step 7.1: Dream Categorization
- [ ] Auto-tag dreams by declared themes
- [ ] Create theme-based dream lists
- [ ] Add theme filters to library

**Testing Checkpoint**:
- [ ] Auto-tagging works accurately
- [ ] Filters function correctly
- [ ] Performance remains good

#### Step 7.2: Theme Insights
- [ ] Create theme statistics
- [ ] Build theme evolution charts
- [ ] Add theme-based recommendations

**Testing Checkpoint**:
- [ ] Statistics calculate correctly
- [ ] Charts render properly
- [ ] Recommendations are relevant

### Phase 8: Goal-Oriented Dashboard
**Goal**: Different UI/features based on primary goal

#### Step 8.1: Create Goal-Specific Views
- [ ] Self-Discovery Dashboard
- [ ] Creativity Board
- [ ] Problem-Solving Workspace
- [ ] Emotional Healing Journey

**Testing Checkpoint**:
- [ ] Each dashboard loads correctly
- [ ] Features match user goal
- [ ] Switching between views works

#### Step 8.2: Goal-Specific Metrics
- [ ] Define metrics per goal
- [ ] Create tracking systems
- [ ] Build progress displays

**Testing Checkpoint**:
- [ ] Metrics track accurately
- [ ] Displays update in real-time
- [ ] Data persists correctly

## Testing Strategy

### For Each Feature:
1. **Unit Tests**: Test individual components
2. **Integration Tests**: Test API endpoints
3. **UI Tests**: Test user interactions
4. **End-to-End Tests**: Test complete flows
5. **User Testing**: Get feedback from 5-10 beta users

### Debug Process:
1. Check logs for errors
2. Verify data flow (frontend → API → database)
3. Test edge cases (no network, empty data, etc.)
4. Performance profiling
5. Fix issues before proceeding

## Success Metrics

### Technical Metrics:
- [ ] All tests passing
- [ ] <2s load time for all screens
- [ ] <500ms API response time
- [ ] 99.9% uptime

### Product Metrics:
- [ ] 80% onboarding completion rate
- [ ] 50% enable notifications
- [ ] 30% increase in dream recording frequency
- [ ] 25% improvement in user retention

## Timeline Estimate

- Phase 1: 3-4 days
- Phase 2: 5-7 days
- Phase 3: 3-4 days
- Phase 4: 2-3 days
- Phase 5: 2-3 days
- Phase 6: 3-4 days
- Phase 7: 3-4 days
- Phase 8: 4-5 days

**Total: 25-35 days**

## Next Steps

1. Start with Phase 1, Step 1.1
2. Complete testing checkpoint before moving on
3. Document any issues or learnings
4. Adjust plan based on discoveries

---

## Implementation Notes

### Current Status
- [x] Phase 1 - ✅ COMPLETED (Backend preferences API fully implemented and tested)
- [x] Phase 2 - ✅ COMPLETED (iOS onboarding flow with data collection and API integration)
- [ ] Phase 3 - Not Started  
- [ ] Phase 4 - Not Started
- [ ] Phase 5 - ⚠️ PARTIAL (Archetype suggestion implemented in onboarding)
- [ ] Phase 6 - Not Started
- [ ] Phase 7 - Not Started
- [ ] Phase 8 - Not Started

### Key Decisions Log

**Phase 1 Implementation (Completed 2025-07-30)**:
- ✅ Database migration `a2385c74dc20_add_user_preferences_table.py` successfully applied
- ✅ Complete preferences model with SQLAlchemy ORM integration
- ✅ Comprehensive Pydantic schemas with validation
- ✅ Full CRUD API endpoints with JWT authentication
- ✅ Archetype suggestion algorithm based on user preferences
- ✅ All API tests passing (5/5) including data persistence verification
- ✅ Repository pattern implemented for data access abstraction

**Technical Architecture**:
- Using PostgreSQL with JSONB for flexible data storage (themes, interests, traits)
- Implemented proper foreign key constraints and database indexes
- Clean separation between domain models, API schemas, and database implementations
- Background task support for profile calculations

**Phase 2 Implementation (Completed 2025-07-30)**:
- ✅ Complete 7-screen onboarding flow implemented in RootView.swift:1534+ lines
- ✅ UserPreferences Swift model with full backend schema compatibility
- ✅ ArchetypeSuggestion model with API integration  
- ✅ Data collection screens: Sleep Patterns, Dream Patterns, Goals/Interests, Notifications
- ✅ Real-time API integration with preferences creation and archetype suggestion
- ✅ Feature flag system for testing (Config.forceOnboardingForTesting)
- ✅ Comprehensive error handling and loading states
- ✅ Archetype reveal screen with personalized welcome experience
- ✅ Debug logging system for development and QA testing

**iOS Architecture**:
- Modular SwiftUI package structure (CoreModels, Features, Configuration, Infrastructure)
- AuthBridge pattern for authentication and onboarding state management
- Comprehensive data binding between UI and UserPreferences model
- Async/await API integration with proper error handling

### Issues & Resolutions
_Track problems encountered and how they were solved_