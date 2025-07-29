# Dream Profile Page Design Document

## Vision
Create a mystical, personalized home screen that makes users feel their dreams are meaningful and part of a cosmic pattern, inspired by Stardust's approach to personal data visualization.

## Core Concept: Dream Keeper System

### Dream Keeper Archetypes
Each user is assigned a "Dream Keeper" - a mystical archetype reflecting their unique dream patterns:

1. **Starweaver** 🌟
   - Profile: Rich symbolic dreams with intricate narratives
   - Colors: Deep purple (#5B2C6F) and gold (#FFD700)
   - Message: "You weave cosmic stories in your sleep"

2. **Moonwalker** 🌙
   - Profile: Journey and exploration themed dreams
   - Colors: Silver (#C0C0C0) and midnight blue (#191970)
   - Message: "You traverse dreamscapes like ancient paths"

3. **Soulkeeper** 💫
   - Profile: Deep emotional and introspective dreams
   - Colors: Teal (#008B8B) and rose (#FFB6C1)
   - Message: "You dive deep into the waters of the soul"

4. **Timeseeker** ⏳
   - Profile: Dreams of past memories or future visions
   - Colors: Amber (#FFBF00) and bronze (#CD7F32)
   - Message: "You walk between yesterday and tomorrow"

5. **Shadowmender** 🌑
   - Profile: Dreams processing fears and challenges
   - Colors: Indigo (#4B0082) and charcoal (#36454F)
   - Message: "You transform shadows into strength"

6. **Lightbringer** ☀️
   - Profile: Uplifting and transcendent dreams
   - Colors: Opal (#A8C3BC) and sunrise (#FFCCCB)
   - Message: "You carry dawn within your dreams"

## Page Layout

### 1. Hero Section (Non-scrollable header)
```
┌─────────────────────────────────┐
│     [Dream Keeper Avatar]       │
│        Starweaver              │
│   "15 nights of dreams"        │
│                                │
│   [Circular Dream Pattern]     │
│   ○○●●●○●●●○○●●●○●●●○         │
└─────────────────────────────────┘
```

### 2. Today's Dream Wisdom (First scroll section)
```
┌─────────────────────────────────┐
│        Tonight's Portal         │
│                                │
│ "The veil grows thin. Your     │
│  dreams seek ancient truths."   │
│                                │
│ Recent Symbols: 🌊 💎 🦋       │
└─────────────────────────────────┘
```

### 3. Dream Landscape (Visual data)
```
┌─────────────────────────────────┐
│     Emotional Tides             │
│   ╱╲    ╱╲     ╱╲             │
│  ╱  ╲╱╲╱  ╲╱╲╱  ╲            │
│ ╱              Joy             │
│ ─────────────────── Fear      │
│                     Wonder     │
└─────────────────────────────────┘
```

### 4. Dream Statistics
```
┌─────────────────────────────────┐
│ Total Dreams: 47                │
│ Longest Dream: 12 minutes       │
│ Dream Themes: Adventure (40%)   │
│               Family (30%)      │
│               Mystery (30%)     │
└─────────────────────────────────┘
```

## Visual Design Specifications

### Typography
- Headers: Avenir-Heavy
- Body: Avenir-Medium
- Accent text: Avenir-Book

### Animations
1. **Archetype Avatar**: Gentle floating animation with particle effects
2. **Dream Pattern**: Slow rotation (360° over 60 seconds)
3. **Emotional Waves**: Smooth sine wave animation
4. **Scroll Effects**: Parallax on background elements

### Color Usage
- Background: Rich black (#000000) with subtle gradient
- Card backgrounds: Semi-transparent with archetype color tint
- Text: White with varying opacity
- Accents: Archetype-specific colors

## Interaction Design

### Tap Interactions
- Dream pattern dots: Show dream summary from that day
- Archetype avatar: Reveal full archetype description
- Emotional waves: Highlight specific emotion path
- Statistics: Drill down to detailed view

### Navigation Flow
```
Login → Profile (default) → Record/Library via tab bar
         ↓
    Dream Entry View (when tapping a dream)
```

## Data Requirements

### For MVP
- Total dream count
- Recent dream dates (for pattern)
- Basic theme extraction from titles
- Placeholder archetype assignment

### Future Enhancements
- AI-powered theme analysis
- Emotional sentiment from transcripts
- Pattern recognition algorithms
- Personalized daily messages
- Social sharing of archetype

## Implementation Notes

### Component Hierarchy
```
ProfileView
├── DreamArchetypeView
│   ├── ArchetypeAvatar
│   └── DreamPatternChart
├── DreamInsightsCard
├── EmotionalLandscapeView
└── DreamStatisticsView
```

### State Management
- ProfileViewModel handles:
  - Dream data aggregation
  - Archetype calculation
  - Daily message generation
  - Statistics computation

### Performance Considerations
- Lazy load dream analysis
- Cache calculated statistics
- Smooth 60fps animations
- Optimize particle effects

## Copy Templates

### Daily Messages by Archetype

**Starweaver**
- "Symbols dance through your sleep tonight"
- "Your dreams weave stories yet untold"
- "The cosmos speaks through your slumber"

**Moonwalker**
- "New paths await in tonight's journey"
- "Your dream feet know ancient roads"
- "Adventure calls from beyond the veil"

**Soulkeeper**
- "Deep waters reflect your inner truth"
- "Emotions rise like tides in sleep"
- "Your heart speaks clearest at night"

**Timeseeker**
- "Past and future merge in dreams"
- "Time bends within your sleeping mind"
- "Memories transform into prophecies"

**Shadowmender**
- "Darkness holds your greatest strength"
- "Fear becomes wisdom in your dreams"
- "Shadows teach what light cannot"

**Lightbringer**
- "Joy illuminates your dream path"
- "You carry dawn within your rest"
- "Light flows through your sleeping soul"

## Success Metrics
- Users check profile daily
- Increased dream recording frequency
- Social shares of archetype
- Positive user feedback on personalization
- Extended app session duration