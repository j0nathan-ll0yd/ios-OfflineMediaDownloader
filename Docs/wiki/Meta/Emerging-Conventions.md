# Emerging Conventions

## Quick Reference
- **When to use**: Capturing new patterns during development
- **Enforcement**: Append-only log
- **Impact if violated**: Medium - Lost institutional knowledge

---

## Overview

This is a living document for capturing emerging patterns and conventions as they're discovered. Entries should be moved to proper wiki pages once mature.

---

## How to Use

### Adding Entries
When you notice a repeating pattern or make a decision that should be documented:

```markdown
## YYYY-MM-DD

**Pattern**: [Short description]
**Signal**: [How you detected it - error, repeated decision, PR feedback]
**Context**: [Why this came up]
**Proposed Action**: [Document in wiki / Discuss with team / Monitor]
```

### Moving to Wiki
Once a pattern is mature (confirmed by team or repeated 3+ times):
1. Create wiki page in appropriate category
2. Update conventions-tracking.md
3. Add reference to AGENTS.md if critical
4. Remove or mark as documented here

---

## Log

### 2025-01-16

**Pattern**: CancelID enum for async effects
**Signal**: DiagnosticFeature was missing CancelID, other features had it
**Context**: All async effects should be cancellable for proper cleanup
**Status**: ✅ Fixed in DiagnosticFeature, documented in Effect-Patterns.md

---

### Documented Conventions (from project setup)

The following patterns were established at project start and have been documented:

| Pattern | Status | Location |
|---------|--------|----------|
| Delegate actions for parent communication | ✅ Documented | [Delegation-Pattern.md](../TCA/Delegation-Pattern.md) |
| State preservation during list refresh | ✅ Documented | [Feature-State-Design.md](../TCA/Feature-State-Design.md) |
| Emoji prefixes for logging categories | ✅ Documented | AGENTS.md (Recommended) |
| Auth error escalation via delegate | ✅ Documented | [Delegation-Pattern.md](../TCA/Delegation-Pattern.md) |
| Background thread for expensive operations | ⏳ Pending | Should add to Performance section |

---

## Pending Investigation

Items that need more observation before documenting:

- [ ] Optimal CoreData merge policy for background updates
- [ ] Best practice for video player audio session setup
- [ ] Error retry patterns for transient network failures

---

## Proposed Conventions

Items proposed but not yet adopted:

| Proposal | Proposed By | Status | Notes |
|----------|-------------|--------|-------|
| - | - | - | - |

---

## Archived

Patterns that were considered but rejected or superseded:

| Pattern | Reason | Date |
|---------|--------|------|
| NotificationCenter for events | Superseded by delegate actions | Project start |
| ObservableObject ViewModels | Superseded by TCA reducers | Project start |

---

## Notes

- This is an append-only log during active development
- Review weekly and move mature patterns to wiki
- Keep entries brief - full documentation goes in wiki
- Date format: YYYY-MM-DD for sorting

---

## Related Patterns
- [Convention-Capture-System.md](../Methodologies/Convention-Capture-System.md)
- [Documentation-Patterns.md](Documentation-Patterns.md)
