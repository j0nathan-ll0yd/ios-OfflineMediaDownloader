# Convention Capture System

## Quick Reference
- **When to use**: During all development work
- **Enforcement**: Recommended
- **Impact if violated**: Medium - Lost institutional knowledge

---

## Overview

The Convention Capture System ensures that emerging patterns and decisions are documented for future reference and AI assistant context.

---

## Detection Signals

Watch for these signals during development:

| Signal | Level | Action |
|--------|-------|--------|
| "NEVER", "FORBIDDEN" | Zero-tolerance | Document immediately |
| "MUST", "REQUIRED", "ALWAYS" | Required | Document within session |
| "Prefer", repeated decisions | Recommended | Document when pattern emerges |
| "Consider", "Might" | Optional | Note in Emerging-Conventions.md |

---

## Convention Lifecycle

```
Detected → Pending → Documented → Active → (Superseded/Archived)
```

### Stages

1. **Detected**: Pattern noticed during development
2. **Pending**: Added to tracking file, awaiting documentation
3. **Documented**: Full wiki page created
4. **Active**: Part of project conventions
5. **Superseded**: Replaced by newer convention
6. **Archived**: No longer applicable

---

## Tracking File

### Location
`docs/conventions-tracking.md`

### Format
```markdown
# Convention Tracking

## Pending Documentation
| Convention | Signal Level | Detected | Notes |
|------------|--------------|----------|-------|
| Cancel IDs required | Required | 2024-01-15 | Effect cancellation pattern |

## Recently Documented
| Convention | Wiki Link | Documented |
|------------|-----------|------------|
| Delegate actions | [Delegation-Pattern.md](wiki/TCA/Delegation-Pattern.md) | 2024-01-10 |

## Proposed
| Convention | Proposed By | Status |
|------------|-------------|--------|
| Emoji logging | Team | Under discussion |

## Archived
| Convention | Reason | Archived |
|------------|--------|----------|
| NotificationCenter events | Superseded by delegate actions | 2024-01-01 |
```

---

## When to Capture

### During Code Review
- Reviewer suggests a pattern → Document if recurring
- PR blocked for convention violation → Add to wiki

### During Development
- Same decision made 3+ times → Candidate for convention
- New error pattern discovered → Document prevention

### During Debugging
- Root cause was convention violation → Strengthen documentation
- Workaround needed → Document edge case

---

## Documentation Template

### Wiki Page Structure
```markdown
# [Convention Name]

## Quick Reference
- **When to use**: [One-line description]
- **Enforcement**: [Zero-tolerance/Required/Recommended]
- **Impact if violated**: [Critical/High/Medium/Low]

---

## The Rule
[Clear, concise statement of the convention]

---

## Examples

### Correct
```swift
// Good example
```

### Incorrect
```swift
// Bad example - what NOT to do
```

---

## Rationale
[Why this convention exists]

---

## Related Patterns
- [Link to related docs]
```

---

## Capture Workflow

### 1. Detection
```markdown
// In Emerging-Conventions.md
## 2024-01-15

Noticed: Cancel IDs should be used for all async effects
Signal: "MUST use cancel IDs" in PR review
Context: Download effect leaked when user navigated away
```

### 2. Pending
```markdown
// In conventions-tracking.md
## Pending Documentation
| Cancel ID Management | Required | 2024-01-15 | Effect cancellation |
```

### 3. Documentation
Create `docs/wiki/TCA/Cancel-ID-Management.md`

### 4. Update Tracking
```markdown
// Move to Recently Documented
## Recently Documented
| Cancel ID Management | [Cancel-ID-Management.md](...) | 2024-01-16 |
```

### 5. Update AGENTS.md
Add reference to new convention in AGENTS.md wiki section.

---

## AI Assistant Integration

### Reading Conventions
AI assistants should:
1. Read AGENTS.md at session start
2. Check conventions-tracking.md for pending items
3. Follow documented patterns

### Capturing Conventions
AI assistants should:
1. Flag when making repeated decisions
2. Suggest documentation for new patterns
3. Update Emerging-Conventions.md

---

## Review Cadence

### Weekly
- Review Emerging-Conventions.md
- Move mature patterns to Pending

### Monthly
- Review Pending conventions
- Document or archive stale items
- Update AGENTS.md with new conventions

### Quarterly
- Review all conventions for relevance
- Archive superseded conventions
- Update enforcement levels

---

## Example: Capturing a Convention

### Scenario
During development, you notice you've had to add `@MainActor` to three different test files.

### Step 1: Note in Emerging Conventions
```markdown
## 2024-01-15
- TCA tests require @MainActor on test functions
- Signal: Compile errors without it
- Times noticed: 3 files
```

### Step 2: Add to Tracking
```markdown
## Pending Documentation
| @MainActor in TCA tests | Required | 2024-01-15 | TestStore requires MainActor |
```

### Step 3: Document
Create documentation explaining the pattern:
- Why it's needed (TestStore uses MainActor)
- How to apply it
- Examples

### Step 4: Reference
Add to AGENTS.md and Swift-Testing-Patterns.md

---

## Anti-Patterns

### Don't over-document
```markdown
// ❌ Too trivial
Convention: Use semicolons at end of statements

// ✅ Meaningful
Convention: All async effects must be cancellable
```

### Don't document opinions as conventions
```markdown
// ❌ Personal preference
Convention: Always use trailing closures

// ✅ Project decision
Convention: Use delegate actions for parent communication
```

---

## Rationale

- **Institutional memory**: Decisions persist beyond team changes
- **Consistency**: New developers follow established patterns
- **AI context**: AI assistants have project-specific knowledge
- **Onboarding**: New team members can learn conventions quickly

---

## Related Patterns
- [Documentation-Patterns.md](../Meta/Documentation-Patterns.md)
- [Working-with-AI-Assistants.md](../Meta/Working-with-AI-Assistants.md)
