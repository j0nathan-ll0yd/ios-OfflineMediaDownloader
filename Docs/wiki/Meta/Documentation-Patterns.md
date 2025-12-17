# Documentation Patterns

## Quick Reference
- **When to use**: Creating or updating documentation
- **Enforcement**: Recommended
- **Impact if violated**: Low - Documentation quality

---

## Overview

This document describes how documentation is organized and maintained in this project.

---

## Documentation Hierarchy

```
Repository Root
├── AGENTS.md           # Primary AI context (comprehensive)
├── CLAUDE.md           # Claude Code pointer → AGENTS.md
├── README.md           # Project overview (if needed)
└── docs/
    ├── wiki/           # Detailed documentation
    │   ├── Conventions/
    │   ├── TCA/
    │   ├── Views/
    │   ├── Testing/
    │   ├── Infrastructure/
    │   ├── Methodologies/
    │   └── Meta/
    └── conventions-tracking.md
```

---

## File Purposes

### AGENTS.md
**Primary context file for AI assistants**
- Project overview and architecture
- Critical rules (zero-tolerance)
- Quick reference patterns
- Links to wiki pages
- Development workflow

**Length**: 400-500 lines
**Updates**: When major patterns change

### CLAUDE.md
**Passthrough for Claude Code CLI**
```markdown
See AGENTS.md for project conventions and patterns.
```

### docs/wiki/
**Detailed documentation by category**
- One file per pattern/convention
- Consistent template structure
- Cross-references between pages
- Full code examples

---

## Wiki Page Template

```markdown
# [Pattern Name]

## Quick Reference
- **When to use**: [One-line description]
- **Enforcement**: [Zero-tolerance/Required/Recommended]
- **Impact if violated**: [Critical/High/Medium/Low]

---

## The Rule
[Clear, concise statement]

---

## [Main Content Sections]
[Detailed explanation with examples]

---

## Examples

### Correct
```swift
// Good example with explanation
```

### Incorrect
```swift
// ❌ Bad example
// Why it's wrong
```

---

## Anti-Patterns
[Common mistakes to avoid]

---

## Rationale
[Why this pattern exists]

---

## Related Patterns
- [Link to related page](relative/path.md)
```

---

## Writing Guidelines

### Be Concise
```markdown
// ❌ Verbose
The reason why we use this pattern is because it provides
several benefits including improved testability, better
separation of concerns, and enhanced maintainability...

// ✅ Concise
Use delegate actions for child-parent communication. This enables
testing and prevents tight coupling.
```

### Use Code Examples
```markdown
// ❌ Abstract
Use the correct pattern for state management

// ✅ Concrete
```swift
@ObservableState
struct State: Equatable {
  var items: IdentifiedArrayOf<ItemFeature.State> = []
}
```

### Show Anti-Patterns
```markdown
// Always include what NOT to do
### Incorrect
```swift
// ❌ FORBIDDEN - Direct state access
NotificationCenter.default.post(...)
```
```

---

## Category Guidelines

### Conventions/
General coding standards:
- Naming conventions
- Git workflow
- Import organization
- File organization

### TCA/
TCA-specific patterns:
- Reducer structure
- State design
- Action naming
- Effects
- Dependencies

### Views/
SwiftUI + TCA integration:
- Store binding
- Navigation
- Child scoping

### Testing/
Test patterns:
- TestStore usage
- Mocking
- Swift Testing

### Infrastructure/
External integrations:
- CoreData
- Keychain
- Push notifications
- Downloads
- Environment config

### Methodologies/
Process documentation:
- Feature implementation guide
- Convention capture system

### Meta/
Documentation about documentation:
- Working with AI
- Documentation patterns
- Emerging conventions

---

## Cross-References

### Within Wiki
```markdown
See [Reducer-Patterns.md](../TCA/Reducer-Patterns.md)
```

### From AGENTS.md
```markdown
- [Reducer-Patterns.md](docs/wiki/TCA/Reducer-Patterns.md)
```

---

## Maintenance

### When to Update
- New pattern established → Add wiki page
- Pattern changed → Update wiki page
- Pattern deprecated → Move to archived section
- FAQ emerges → Add to relevant page

### Review Schedule
- **Weekly**: Check Emerging-Conventions.md
- **Monthly**: Review and update wiki pages
- **Quarterly**: Audit AGENTS.md completeness

---

## Enforcement Levels

| Level | Meaning | Documentation |
|-------|---------|---------------|
| Zero-tolerance | NEVER violate | AGENTS.md + Wiki page |
| Required | MUST follow | Wiki page |
| Recommended | SHOULD follow | Wiki page or note |
| Optional | MAY follow | Note in related page |

---

## Version Control

### Commit Messages
```
docs: add TCA reducer patterns wiki page
docs: update AGENTS.md with new dependency pattern
docs: fix broken link in Testing section
```

### PR Guidelines
- Documentation changes can be separate PRs
- Large pattern changes should include doc updates
- Cross-reference in PR description

---

## Anti-Patterns

### Don't Duplicate
```markdown
// ❌ Same content in multiple places
// AGENTS.md: [full pattern explanation]
// Wiki page: [same full pattern explanation]

// ✅ Reference
// AGENTS.md: [quick reference + link]
// Wiki page: [full pattern explanation]
```

### Don't Over-Document
```markdown
// ❌ Documenting obvious Swift syntax
How to create a struct...

// ✅ Documenting project decisions
Why we use @ObservableState instead of @Observable...
```

### Don't Let Docs Get Stale
```markdown
// ❌ Outdated example using old API
// ✅ Regular review and updates
```

---

## Rationale

- **Discoverability**: Organized structure helps find information
- **Maintainability**: Consistent format easy to update
- **AI context**: Structured docs improve AI assistance
- **Onboarding**: New developers can learn quickly

---

## Related Patterns
- [Convention-Capture-System.md](../Methodologies/Convention-Capture-System.md)
- [Working-with-AI-Assistants.md](Working-with-AI-Assistants.md)
