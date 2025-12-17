# Working with AI Assistants

## Quick Reference
- **When to use**: When collaborating with AI coding assistants
- **Enforcement**: Recommended
- **Impact if violated**: Low - Reduced AI effectiveness

---

## Overview

This guide helps you work effectively with AI assistants (Claude, GitHub Copilot, etc.) on this TCA iOS codebase.

---

## Context Files

### AGENTS.md
The primary context file for AI assistants. Contains:
- Project architecture
- Critical rules and conventions
- TCA patterns and templates
- Development workflow

### CLAUDE.md
Points to AGENTS.md for Claude Code CLI.

### docs/wiki/
Detailed documentation organized by topic.

---

## Effective Prompting

### Provide Context
```
// ❌ Vague
Add a new feature for settings

// ✅ Specific
Add a SettingsFeature using TCA patterns. It should:
- Display user preferences (notifications on/off, theme)
- Allow toggling notification setting via KeychainClient
- Use delegate action to notify parent when theme changes
- Follow patterns in FileListFeature for structure
```

### Reference Existing Code
```
// ✅ Good
Create a DiagnosticFeature similar to FileListFeature, but for
displaying keychain items. Use the same delegate pattern for
handling item deletion.
```

### Specify Constraints
```
// ✅ Good
Add download progress tracking. Constraints:
- Must use cancel IDs for the download effect
- Progress updates via AsyncStream
- Preserve download state during list refresh
- Follow existing FileCellFeature patterns
```

---

## Common Tasks

### Adding a New Feature
```
Create a new TCA feature called [Name]Feature that:
1. [Primary functionality]
2. [Secondary functionality]
3. Uses dependencies: [list]
4. Communicates with parent via delegate actions for: [list]

Follow the patterns in:
- Reducer: docs/wiki/TCA/Reducer-Patterns.md
- View: docs/wiki/Views/Store-Integration.md
- Delegation: docs/wiki/TCA/Delegation-Pattern.md
```

### Adding a Dependency Client
```
Create a [Name]Client dependency that:
1. Method 1: [signature and purpose]
2. Method 2: [signature and purpose]

Include:
- @DependencyClient definition
- DependencyValues extension
- liveValue with production implementation
- testValue with stubs

Follow patterns in ServerClient.swift
```

### Fixing a Bug
```
Bug: [Description of bug]
Expected: [What should happen]
Actual: [What's happening]

Likely locations:
- [File1.swift] - [why]
- [File2.swift] - [why]

Please investigate and propose a fix following project conventions.
```

### Adding Tests
```
Add tests for [Feature]Feature covering:
1. [Scenario 1]
2. [Scenario 2]
3. Error handling for [error type]

Use TestStoreOf<Feature> pattern from docs/wiki/Testing/TestStore-Usage.md
Mock dependencies using patterns from docs/wiki/Testing/Dependency-Mocking.md
```

---

## Zero-Tolerance Checklist

When reviewing AI-generated code, verify:

- [ ] No `@State` or `@StateObject` in TCA views
- [ ] All services use `@DependencyClient`
- [ ] Parent communication via delegate actions (not NotificationCenter)
- [ ] `@ObservableState` on all State structs
- [ ] Cancel IDs for async operations
- [ ] Dependencies have both liveValue and testValue

---

## Iterative Refinement

### Initial Request
```
Add a search feature to FileListView
```

### Review Output
Check against conventions, then refine:

```
Good start. Please adjust:
1. Add CancelID for search debouncing
2. Use cancelInFlight: true to cancel previous searches
3. Add errorMessage handling for search failures
4. Ensure search state is preserved during refresh
```

### Verify
After changes:
```
Looks good. Can you add tests for:
1. Search with results
2. Search with empty results
3. Search cancelled by new query
4. Search error handling
```

---

## Documentation Updates

When AI adds new patterns:

```
You added a new pattern for [X]. Please:
1. Update docs/wiki/[Category]/[Page].md with this pattern
2. Add an entry to docs/wiki/Meta/Emerging-Conventions.md
3. If it's a critical pattern, mention it in AGENTS.md
```

---

## Troubleshooting

### AI Generates Old Patterns
```
This uses ObservableObject which is MVVM pattern. Please use:
- @Reducer macro
- @ObservableState
- StoreOf<Feature>
See AGENTS.md TCA Patterns Reference section.
```

### AI Uses NotificationCenter
```
This project uses delegate actions, not NotificationCenter.
See docs/wiki/TCA/Delegation-Pattern.md for the correct approach.
```

### AI Creates @State in View
```
TCA views should not have @State. All state must be in the feature's
State struct. Move [property] to the feature state and add corresponding
actions.
```

---

## Best Practices

### Do
- Reference specific documentation files
- Provide examples from existing code
- Ask for tests alongside features
- Request documentation updates

### Don't
- Accept code that violates zero-tolerance rules
- Skip verification against conventions
- Assume AI knows project-specific patterns
- Forget to check for proper dependency injection

---

## AI Tool Configuration

### Claude Code
Ensure CLAUDE.md exists and references AGENTS.md:
```
See AGENTS.md for project conventions and patterns.
```

### GitHub Copilot
Add comments referencing patterns:
```swift
// Follow TCA patterns from AGENTS.md
// Use delegate actions for parent communication
```

---

## Rationale

- **Efficiency**: AI produces correct code faster with good context
- **Consistency**: AI follows project conventions
- **Quality**: Iterative refinement catches issues early
- **Learning**: AI output improves with feedback

---

## Related Patterns
- [Convention-Capture-System.md](../Methodologies/Convention-Capture-System.md)
- [Documentation-Patterns.md](Documentation-Patterns.md)
