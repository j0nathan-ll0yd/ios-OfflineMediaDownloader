# Convention Tracking

Central registry for tracking convention documentation lifecycle.

---

## Documented Conventions

Conventions that have been fully documented in the wiki.

### Zero-Tolerance Rules
| Convention | Wiki Link | Enforcement |
|------------|-----------|-------------|
| No @State/@StateObject in TCA Views | [Store-Integration.md](wiki/Views/Store-Integration.md) | Zero-tolerance |
| @DependencyClient Required | [Dependency-Client-Design.md](wiki/TCA/Dependency-Client-Design.md) | Zero-tolerance |
| Delegate Actions for Parent Communication | [Delegation-Pattern.md](wiki/TCA/Delegation-Pattern.md) | Zero-tolerance |

### Required Patterns
| Convention | Wiki Link | Category |
|------------|-----------|----------|
| @ObservableState on State | [Feature-State-Design.md](wiki/TCA/Feature-State-Design.md) | TCA |
| Cancel IDs for Async Operations | [Cancel-ID-Management.md](wiki/TCA/Cancel-ID-Management.md) | TCA |
| liveValue + testValue for Dependencies | [Dependency-Client-Design.md](wiki/TCA/Dependency-Client-Design.md) | TCA |
| @Reducer Macro Structure | [Reducer-Patterns.md](wiki/TCA/Reducer-Patterns.md) | TCA |
| Effect Patterns | [Effect-Patterns.md](wiki/TCA/Effect-Patterns.md) | TCA |
| Action Naming | [Action-Naming.md](wiki/TCA/Action-Naming.md) | TCA |
| @Bindable Store Integration | [Store-Integration.md](wiki/Views/Store-Integration.md) | Views |
| Child Feature Scoping | [Child-Feature-Scoping.md](wiki/Views/Child-Feature-Scoping.md) | Views |
| Navigation State-Driven | [Navigation-Patterns.md](wiki/Views/Navigation-Patterns.md) | Views |
| Binding Patterns | [Binding-Patterns.md](wiki/Views/Binding-Patterns.md) | Views |
| TestStore Usage | [TestStore-Usage.md](wiki/Testing/TestStore-Usage.md) | Testing |
| Dependency Mocking | [Dependency-Mocking.md](wiki/Testing/Dependency-Mocking.md) | Testing |
| Swift Testing (@Test) | [Swift-Testing-Patterns.md](wiki/Testing/Swift-Testing-Patterns.md) | Testing |
| CoreData via Client | [CoreData-Integration.md](wiki/Infrastructure/CoreData-Integration.md) | Infrastructure |
| Keychain via Valet | [Keychain-Storage-Valet.md](wiki/Infrastructure/Keychain-Storage-Valet.md) | Infrastructure |
| Environment Configuration | [Environment-Configuration.md](wiki/Infrastructure/Environment-Configuration.md) | Infrastructure |
| Push Notification Routing | [Push-Notification-Flow.md](wiki/Infrastructure/Push-Notification-Flow.md) | Infrastructure |
| Background Downloads | [Background-Downloads.md](wiki/Infrastructure/Background-Downloads.md) | Infrastructure |
| Naming Conventions | [Naming-Conventions.md](wiki/Conventions/Naming-Conventions.md) | Conventions |
| Git Workflow | [Git-Workflow.md](wiki/Conventions/Git-Workflow.md) | Conventions |
| Import Organization | [Import-Organization.md](wiki/Conventions/Import-Organization.md) | Conventions |
| File Organization | [File-Organization.md](wiki/Conventions/File-Organization.md) | Conventions |

### Recommended Patterns
| Convention | Wiki Link | Category |
|------------|-----------|----------|
| Emoji Logging Prefixes | AGENTS.md | Logging |
| State Preservation During Refresh | [Feature-State-Design.md](wiki/TCA/Feature-State-Design.md) | TCA |
| Feature Implementation Guide | [Feature-Implementation-Guide.md](wiki/Methodologies/Feature-Implementation-Guide.md) | Methodology |

---

## Pending Documentation

Patterns identified but not yet documented.

| Convention | Signal Level | Detected | Notes |
|------------|--------------|----------|-------|
| - | - | - | - |

---

## Proposed Conventions

Patterns under consideration.

| Convention | Proposed By | Status | Notes |
|------------|-------------|--------|-------|
| - | - | - | - |

---

## Recently Documented

Conventions documented in the last 30 days.

| Convention | Wiki Link | Documented | By |
|------------|-----------|------------|-----|
| All initial conventions | Various | 2024-XX-XX | Initial documentation |

---

## Archived/Superseded

Conventions no longer in use.

| Convention | Reason | Archived |
|------------|--------|----------|
| NotificationCenter Events | Superseded by delegate actions | Project start |
| ObservableObject ViewModels | Superseded by TCA @Reducer | Project start |
| Direct Service Instantiation | Superseded by @DependencyClient | Project start |

---

## Statistics

| Category | Count |
|----------|-------|
| Zero-tolerance | 3 |
| Required | 22 |
| Recommended | 3 |
| **Total Documented** | **28** |

---

## Review Schedule

- **Weekly**: Check Emerging-Conventions.md, move mature patterns here
- **Monthly**: Audit pending conventions, update statistics
- **Quarterly**: Full review of all documented conventions

---

## Related Files

- [AGENTS.md](../AGENTS.md) - Primary AI context
- [Emerging-Conventions.md](wiki/Meta/Emerging-Conventions.md) - New patterns log
- [Convention-Capture-System.md](wiki/Methodologies/Convention-Capture-System.md) - Process guide
