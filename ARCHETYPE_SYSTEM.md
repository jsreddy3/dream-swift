# Dream Archetype System

## Overview
Our archetype system categorizes users into six scientifically-grounded dreamer types based on their onboarding responses. Each archetype is backed by academic research in dream psychology and neuroscience.

## The Six Archetypes

### 🧠 **Analytical Dreamer**
**Description:**
> "Your dreams quietly process and organize your daily experiences, reflecting your practical approach to life. According to psychologist Dr. Ernest Hartmann, you're likely a 'thick-boundary dreamer'—someone who naturally prefers structure and clear emotional boundaries, finding clarity primarily in waking thought rather than elaborate dream symbolism."

**Academic Reference:** Psychologist Dr. Ernest Hartmann – Thick-Boundary Dreaming Theory

**Triggers:**
- Primary goals: problem_solving, self_discovery (practical aspects)
- Dream recall: rarely, never
- Dream vividness: vague, moderate
- Themes: work, school, daily_activities

---

### 🌊 **Reflective Dreamer**
**Description:**
> "Your dreams help you process emotional experiences, manage relationships, and build psychological resilience. Dream researcher Dr. Rosalind Cartwright suggests that dreamers like you instinctively utilize dreaming as an emotional coping mechanism, resolving inner conflicts and fostering emotional adaptation."

**Academic Reference:** Dream researcher Dr. Rosalind Cartwright – Dreams as Emotional Adaptation

**Triggers:**
- Primary goals: emotional_healing, self_discovery (emotional aspects)
- Dream recall: sometimes, often
- Dream vividness: moderate, vivid
- Themes: family, relationships, emotions, water

---

### 🔍 **Introspective Dreamer**
**Description:**
> "You regularly experience vivid, symbolic dreams, revealing deep insights into your inner life. According to psychologist Dr. Michael Schredl, dreamers with high recall and introspection—like you—often possess traits such as openness, sensitivity, and a profound curiosity about their inner worlds."

**Academic Reference:** Psychologist Dr. Michael Schredl – Dream Recall and Personality Research

**Triggers:**
- Primary goals: self_discovery, spiritual_growth
- Dream recall: often, always
- Dream vividness: vivid, very_vivid
- Themes: symbolism, mystery, supernatural

---

### 🌀 **Lucid Dreamer**
**Description:**
> "Your vivid, sometimes controllable dreams indicate exceptional self-awareness, imagination, and curiosity. Lucid dreaming pioneer Dr. Stephen LaBerge identifies dreamers like you as having strong metacognitive abilities, capable of consciously exploring their dream worlds with intention."

**Academic Reference:** Psychophysiologist Dr. Stephen LaBerge – Lucid Dreaming and Metacognition

**Triggers:**
- Primary goals: lucid_dreaming
- Dream recall: often, always
- Dream vividness: very_vivid
- Themes: flying, control, awareness
- Interests: lucid_dreaming

---

### 🎨 **Creative Dreamer**
**Description:**
> "Your dreams overflow with imaginative and symbolic content, providing a wellspring for creative thought and inspiration. Psychologist Dr. Ernest Hartmann identifies dreamers like you as 'thin-boundary dreamers,' naturally inclined to vivid imagination and creative integration between waking life and dreams."

**Academic Reference:** Psychologist Dr. Ernest Hartmann – Thin-Boundary Dreaming Theory

**Triggers:**
- Primary goals: creativity
- Dream recall: sometimes, often, always
- Dream vividness: vivid, very_vivid
- Themes: adventure, fantasy, nature, art
- Interests: creativity, symbolism

---

### ⚙️ **Resolving Dreamer**
**Description:**
> "Your dreams frequently revisit unresolved issues, helping you rehearse possibilities, solve problems, and address emotional or practical challenges. According to psychologist Dr. G. William Domhoff, dreams commonly function as natural problem-solving mechanisms, a trait especially pronounced among dreamers like you."

**Academic Reference:** Psychologist Dr. G. William Domhoff – Dreams as Problem-solving Mechanisms

**Triggers:**
- Primary goals: problem_solving, emotional_healing
- Dream recall: sometimes, often
- Dream vividness: moderate, vivid
- Themes: being_chased, work, recurring_scenarios
- Interests: problem_solving, nightmare_resolution

---

## Scoring Algorithm

### Point Values:
- **Primary Goal**: 3 points
- **Dream Recall Frequency**: 2 points
- **Dream Vividness**: 2 points
- **Dream Themes**: 1 point each (max 3 themes counted)
- **Interests**: 1 point each (max 2 interests counted)

### Calculation Process:
1. Initialize all archetype scores to 0
2. Add points based on user selections according to trigger mappings
3. Select archetype with highest score
4. If tied, prioritize based on: Introspective > Creative > Reflective > Lucid > Resolving > Analytical
5. Calculate confidence: 80% + (score/12 × 15%) = 80-95% range

### Default:
If no clear winner (all scores 0), default to **Analytical Dreamer** with 80% confidence.

## Implementation Notes

### Frontend Display:
- Show archetype name with emoji
- Display full description with academic reference
- Option to "Learn More" showing the researcher's work
- Confidence indicator (visual bar or percentage)

### Backend Mapping:
```python
ARCHETYPE_MAPPING = {
    "analytical": {
        "name": "Analytical Dreamer",
        "symbol": "🧠",
        "researcher": "Dr. Ernest Hartmann",
        "theory": "Thick-Boundary Dreaming Theory"
    },
    # ... etc
}
```

### User Experience:
1. Complete onboarding questionnaire
2. Backend calculates archetype based on responses
3. Archetype reveal screen shows result with academic backing
4. Profile page displays archetype with option to learn more
5. Future: Track if dream patterns align with initial archetype

## Migration from Old System
- Map old archetypes to new ones:
  - starweaver → introspective
  - moonwalker → lucid
  - soulkeeper → reflective
  - timeseeker → resolving
  - shadowmender → resolving
  - lightbringer → creative

## Future Enhancements
- Add "archetype evolution" tracking as users record more dreams
- Provide personalized insights based on archetype
- Suggest dream exercises tailored to each type
- Connect users with similar archetypes in community features