# iOS OfflineMediaDownloader - Comprehensive Evaluation Prompts

**Generated**: 2026-01-19
**Project**: ios-OfflineMediaDownloader
**Architecture**: TCA 1.22.2+, Swift 6.1, iOS 18+
**Current Grade**: B+ (per IMPROVEMENT_PLAN.md)

---

## Overview

This document contains structured evaluation prompts for Claude instances to deeply analyze the OfflineMediaDownloader iOS project. Each prompt is self-contained with context, files to analyze, specific questions, and web research references.

**Categories:**
1. [Testing Evaluation](#1-testing-evaluation-prompts) (5 prompts)
2. [Documentation Evaluation](#2-documentation-evaluation-prompts) (4 prompts)
3. [Scripts Evaluation](#3-scripts-evaluation-prompts) (3 prompts)
4. [Dependencies Evaluation](#4-dependencies-evaluation-prompts) (3 prompts)
5. [Architecture & Security Evaluation](#5-architecture-evaluation-prompts) (4 prompts)
6. [Additional Areas](#6-additional-evaluation-prompts) (3 prompts)

---

## 1. Testing Evaluation Prompts

### Prompt 1.1: Unit Test Coverage Analysis

```
Analyze the unit test coverage for this iOS TCA project.

**Context:**
- Project uses Swift Testing framework (@Test, @Suite, #expect)
- TCA TestStore for reducer testing
- TestData.swift provides centralized fixtures
- ~192 test cases across 13 feature test files
- iOS 26+ only (no backwards compatibility testing needed)

**Files to Analyze:**
- All files in: OfflineMediaDownloaderTests/
- Cross-reference with: App/Features/*.swift

**Questions to Answer:**
1. Which features have corresponding test files? Create a coverage matrix.
2. For each reducer, are all action pathways tested (success, failure, edge cases)?
3. Do tests properly verify state mutations using TestStore closure syntax?
4. Are async effects properly tested with await store.receive()?
5. What critical paths lack test coverage (authentication, downloads, error handling)?

**Output Format:**
| Feature | Test File | Actions Tested | Missing Coverage |
|---------|-----------|----------------|------------------|

**Critical Conventions (from AGENTS.md):**
- All dependencies MUST have testValue implementations
- Cancel IDs required for async operations
- Delegate actions for parent-child communication

**Web Research References:**
- Swift Testing framework best practices: https://fatbobman.com/en/posts/mastering-the-swift-testing-framework/
- TCA Testing patterns: https://www.brightec.co.uk/blog/how-to-test-with-the-composable-architecture
- Apple Swift Testing docs: https://developer.apple.com/xcode/swift-testing
```

---

### Prompt 1.2: TCA TestStore Pattern Quality

```
Evaluate the quality of TCA TestStore usage in this project's tests.

**Context:**
- TCA 1.22.2+ requires specific testing patterns
- Tests should use withDependencies for dependency injection
- store.exhaustivity controls strict action verification
- Project convention: @DependencyClient required for all services

**Files to Analyze:**
- OfflineMediaDownloaderTests/RootFeatureTests.swift
- OfflineMediaDownloaderTests/LoginFeatureTests.swift
- OfflineMediaDownloaderTests/FileListFeatureTests.swift
- OfflineMediaDownloaderTests/DownloadClientTests.swift
- OfflineMediaDownloaderTests/TestData.swift

**Questions to Answer:**
1. Are dependencies consistently overridden using withDependencies?
2. Is exhaustivity properly managed (.off only when timing is non-deterministic)?
3. Are delegate actions tested for parent-child communication?
4. Is the receive() pattern used correctly for async effects?
5. Are CancelID effects properly handled in tests?

**Quality Criteria:**
- Dependency isolation: Each test should mock all external dependencies
- State verification: Closures should verify exact state changes
- Effect verification: All emitted effects should be received

**TCA Template Reference (from AGENTS.md):**
```swift
@MainActor
@Test func example() async throws {
  let store = TestStoreOf<MyFeature>(initialState: MyFeature.State()) {
    MyFeature()
  }
  await store.send(.someAction) {
    $0.someState = expectedValue
  }
}
```

**Web Research References:**
- TCA Dependency Injection 2025: https://medium.com/@gauravios/dependency-injection-in-the-composable-architecture-an-architects-perspective-9be5571a0f89
- Point-Free Testing docs: https://www.pointfree.co/collections/composable-architecture/testing
```

---

### Prompt 1.3: Test Data & Helpers Quality

```
Evaluate the test infrastructure quality and organization.

**Context:**
- Project has TestData.swift for centralized fixtures
- MockURLProtocol used for network testing in DownloadClientTests
- Swift Testing framework with @Test and #expect
- All features use @DependencyClient pattern requiring testValue

**Files to Analyze:**
- OfflineMediaDownloaderTests/TestData.swift
- App/Helpers/TestHelper.swift
- OfflineMediaDownloaderTests/DownloadClientTests.swift (MockURLProtocol)
- APITypes/Sources/APITypes/ (generated response types)

**Questions to Answer:**
1. Is TestData.swift comprehensive? What fixtures are missing?
2. Are test fixtures realistic (valid JWTs, proper response structures)?
3. Is MockURLProtocol properly implemented for network testing?
4. Are there opportunities for shared test utilities?
5. Do fixtures match actual API response structures from APITypes?
6. Are all 15 dependency clients covered with testValue implementations?

**Improvement Areas to Evaluate:**
- Fixture factory patterns vs. static fixtures
- Property-based testing opportunities
- Snapshot testing infrastructure (FileCellSnapshotTests exists)

**Dependency Clients Requiring testValue (from AGENTS.md):**
- ServerClient, KeychainClient, AuthenticationClient
- CoreDataClient, DownloadClient, FileClient
- NotificationClient, and others

**Web Research References:**
- iOS Unit Testing 2025 strategies: https://medium.com/@Rutik_Maraskolhe/unit-testing-in-ios-2025-cutting-edge-strategies-tools-and-trends-for-high-quality-apps-eee2876e47ba
- swift-snapshot-testing: https://github.com/pointfreeco/swift-snapshot-testing
```

---

### Prompt 1.4: Mutation Testing Gap Analysis

```
Identify mutation testing opportunities for this iOS project.

**Context:**
- No mutation testing currently implemented
- Muter is the primary Swift mutation testing tool
- Current test count: ~192 tests
- Code coverage reported at 80%+ target (from IMPROVEMENT_PLAN.md)

**Files to Analyze:**
- All test files in OfflineMediaDownloaderTests/
- App/Features/*.swift (11 reducers to mutate)
- App/Dependencies/*.swift (15 dependency clients to mutate)

**Questions to Answer:**
1. Which reducers have sufficient test coverage to benefit from mutation testing?
2. What mutation operators would be most valuable (arithmetic, boundary, logical)?
3. Estimate effort to integrate Muter into CI/CD pipeline
4. What code areas likely have tests that would survive mutations?

**Recommended Mutations to Test:**
- State property mutations in reducers (isLoading, errorMessage, etc.)
- Error handling path mutations (success vs failure branches)
- Boundary condition mutations (empty arrays, nil values)
- Cancel ID mutations (verify effects are properly cancelled)

**High-Value Mutation Targets:**
- FileListFeature (complex state management)
- DownloadClient (async operations)
- ServerClient (error handling paths)

**Web Research References:**
- Muter mutation testing: https://github.com/muter-mutation-testing/muter
- iOS code coverage tools: https://about.codecov.io/blog/code-coverage-for-ios-development-using-swift-xcode-and-github-actions/
```

---

### Prompt 1.5: CI/CD Test Integration Evaluation

```
Evaluate the CI/CD test pipeline configuration.

**Context:**
- CI currently has issues: "Unit tests disabled due to host app crash during bootstrap"
- Tests run on iOS 18+ simulators only
- Project uses GitHub Actions
- Development.xcconfig provides CI placeholder values

**Files to Analyze:**
- .github/workflows/tests.yml
- .github/dependabot.yml
- Development.xcconfig (CI placeholder values)
- OfflineMediaDownloaderTests/ (test organization)

**Critical Issue (from IMPROVEMENT_PLAN.md):**
```yaml
# From .github/workflows/tests.yml
-only-testing:OfflineMediaDownloaderUITests  # Unit tests disabled!
```

**Questions to Answer:**
1. Is the test workflow comprehensive (build, test, artifact upload)?
2. Are test timeouts appropriate (currently 300s per test)?
3. Is the simulator selection robust for iOS 18+?
4. Are test results properly reported (JUnit XML)?
5. What is causing the "host app crash during bootstrap" issue?
6. What additional CI checks would improve quality?

**Improvement Opportunities:**
- Code coverage reporting to Codecov (currently missing)
- Mutation testing in CI
- Performance regression tests
- UI test stability improvements
- Re-enable unit tests after fixing bootstrap crash

**Web Research References:**
- GitHub Actions iOS CI/CD 2025: https://brightinventions.pl/blog/ios-build-run-tests-github-actions/
- Xcode CI optimization: https://qualitycoding.org/github-actions-ci-xcode/
```

---

## 2. Documentation Evaluation Prompts

### Prompt 2.1: Wiki Structure & Completeness

```
Evaluate the documentation wiki structure and completeness.

**Context:**
- 30+ markdown files across 9 categories
- 8,200+ total lines of documentation
- Categories: TCA/, Views/, Testing/, Infrastructure/, Conventions/, Meta/, Methodologies/
- AGENTS.md serves as master reference (650+ lines)

**Files to Analyze:**
- Docs/wiki/**/*.md (all wiki files)
- AGENTS.md (master reference)
- CLAUDE.md (AI instructions)
- IMPROVEMENT_PLAN.md (existing evaluation)

**Wiki Categories:**
- Conventions/ (4 files): Naming, Git, Imports, Files
- TCA/ (7 files): Reducers, State, Actions, Delegation, Effects, Dependencies, CancelID
- Views/ (4 files): Store Integration, Bindings, Scoping, Navigation
- Testing/ (3 files): TestStore, Mocking, Swift Testing
- Infrastructure/ (5 files): CoreData, Keychain, Push, Downloads, Environment
- Meta/ (3 files): Docs patterns, AI assistants, Emerging conventions
- Methodologies/ (2 files): Feature implementation, Convention capture

**Questions to Answer:**
1. Is the wiki hierarchy logical and discoverable?
2. Are all critical conventions documented?
   - API key as query parameter (not header)
   - iOS 26+ only (no backwards compatibility)
   - Parent-child data sharing pattern
3. What topics are documented but outdated?
4. What topics are missing entirely?
5. Is cross-referencing between documents consistent?

**Completeness Checklist:**
- [ ] All 11 features have pattern documentation
- [ ] All 15 dependency clients have usage examples
- [ ] Error handling patterns documented
- [ ] Navigation patterns documented
- [ ] Background download flow documented

**Web Research References:**
- Technical wiki best practices: https://fullscale.io/blog/build-a-technical-wiki-engineers-actually-use/
- Developer onboarding 2025: https://www.cortex.io/post/developer-onboarding-guide
```

---

### Prompt 2.2: Code Example Accuracy

```
Verify that documentation code examples match actual implementations.

**Context:**
- Wiki contains code templates for TCA patterns
- AGENTS.md has canonical examples for reducers, views, and dependencies
- Project uses TCA 1.22.2+ with @ObservableState requirement

**Files to Cross-Reference:**
- Docs/wiki/TCA/Reducer-Patterns.md ↔ App/Features/*.swift
- Docs/wiki/TCA/Dependency-Client-Design.md ↔ App/Dependencies/*.swift
- Docs/wiki/Views/Store-Integration.md ↔ App/Views/*.swift
- AGENTS.md ↔ All source files

**Critical Convention Examples (from CLAUDE.md):**
```swift
// ✅ CORRECT - Query parameter
request.path = "\(currentPath)?ApiKey=\(apiKey)"

// ❌ WRONG - Header (DO NOT USE)
request.headerFields["X-API-Key"] = apiKey
```

**Questions to Answer:**
1. Do reducer template examples match actual feature implementations?
2. Are dependency client examples using current @DependencyClient patterns?
3. Do view integration examples show current @Bindable patterns?
4. Are import statements in examples correct?
5. Do examples compile with current TCA 1.22.2+?

**Output Format:**
| Document | Example | Source File | Status | Fix Required |
|----------|---------|-------------|--------|--------------|

**Key Patterns to Verify:**
- @ObservableState on all State structs
- @Bindable var store: StoreOf<Feature>
- Delegate actions for parent communication
- Cancel ID enum for async operations

**Web Research References:**
- DocC documentation standards: https://swiftwithmajid.com/2025/04/01/documenting-your-code-with-docc/
- Apple writing documentation: https://developer.apple.com/documentation/xcode/writing-documentation
```

---

### Prompt 2.3: Architecture Decision Records Assessment

```
Evaluate whether the project would benefit from formal ADRs.

**Context:**
- Project has CLAUDE.md with "Critical Conventions (DO NOT CHANGE)"
- IMPROVEMENT_PLAN.md documents some decisions
- No formal ADR directory exists
- Emerging-Conventions.md captures new patterns

**Files to Analyze:**
- CLAUDE.md (existing critical rules)
- IMPROVEMENT_PLAN.md (evaluation decisions)
- Docs/wiki/Meta/Emerging-Conventions.md

**Existing Critical Decisions (from CLAUDE.md):**
1. API key MUST be sent as query parameter, NOT as header
2. iOS 26+ only - no backwards compatibility code
3. Parent-child data sharing pattern (avoid duplicate API calls)

**Questions to Answer:**
1. What architectural decisions should be formally documented as ADRs?
2. Should existing "Critical Conventions" be migrated to ADR format?
3. What ADR template would fit this project (MADR, simple)?
4. Where should ADRs live (Docs/adr/ or Docs/wiki/ADR/)?

**Candidate ADRs to Create:**
- ADR-001: API key as query parameter (not header) - commit 244478b
- ADR-002: iOS 26+ minimum with no backwards compatibility
- ADR-003: TCA as architectural framework
- ADR-004: Parent-child data sharing pattern
- ADR-005: Valet + Secure Enclave for keychain storage
- ADR-006: OpenAPI spec sync from backend TypeSpec

**ADR Template (MADR format):**
```markdown
# ADR-NNN: Title

## Status
Accepted | Deprecated | Superseded

## Context
What is the issue we're seeing that motivates this decision?

## Decision
What is the change we're proposing?

## Consequences
What becomes easier or harder as a result?
```

**Web Research References:**
- MADR template: https://adr.github.io/madr/
- Google Cloud ADR guide: https://docs.cloud.google.com/architecture/architecture-decision-records
- Microsoft Azure ADR guide: https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record
```

---

### Prompt 2.4: DocC Integration Opportunity

```
Assess the value of adopting DocC for API documentation.

**Context:**
- Project currently uses wiki markdown only
- 15 dependency clients could have DocC documentation
- Swift 6.1 has full DocC support
- APITypes package uses swift-openapi-generator

**Files to Analyze:**
- App/Dependencies/*.swift (15 clients)
- App/Features/*.swift (11 features)
- App/Models/*.swift (domain models)
- APITypes/Sources/APITypes/ (generated types)

**Dependency Clients (from AGENTS.md):**
| File | Client | Responsibility |
|------|--------|----------------|
| ServerClient.swift | ServerClient | HTTP API |
| KeychainClient.swift | KeychainClient | Valet storage |
| AuthenticationClient.swift | AuthenticationClient | Apple ID state |
| CoreDataClient.swift | CoreDataClient | File persistence |
| DownloadClient.swift | DownloadClient | URLSession downloads |

**Questions to Answer:**
1. Would DocC provide value over current wiki approach?
2. Which types would benefit most from DocC documentation?
3. What effort would DocC adoption require?
4. Should DocC replace or supplement wiki documentation?

**DocC Adoption Criteria:**
- API surface complexity
- External consumer likelihood
- Documentation navigation needs
- Code-to-docs sync requirements

**Recommended DocC Candidates:**
- ServerClient (external API integration)
- DownloadClient (complex async operations)
- CoreDataClient (data persistence patterns)
- AppError enum (error handling)

**Web Research References:**
- Swift DocC overview: https://www.swift.org/documentation/docc/
- swift-docc GitHub: https://github.com/swiftlang/swift-docc
```

---

## 3. Scripts Evaluation Prompts

### Prompt 3.1: Shell Script Quality Analysis

```
Evaluate the quality and robustness of project shell scripts.

**Context:**
- Project has multiple shell scripts for validation and automation
- Scripts enforce TCA conventions and iOS version requirements
- Pre-commit hooks available via setup-hooks.sh

**Files to Analyze:**
- Scripts/validate-tca-patterns.sh
- Scripts/check-build-warnings.sh
- Scripts/setup-hooks.sh
- Scripts/sync-openapi.sh
- Scripts/validate-ios-version.sh

**Questions to Answer:**
1. Do scripts use proper error handling (set -e, exit codes)?
2. Are scripts portable (shellcheck compliant)?
3. Do scripts provide helpful error messages?
4. Are scripts idempotent (safe to run multiple times)?
5. Is logging/output consistent across scripts?

**Quality Checklist:**
- [ ] Shebang consistency (#!/bin/bash vs #!/bin/sh)
- [ ] Error handling with meaningful exit codes
- [ ] Input validation
- [ ] Color output for readability
- [ ] Help/usage documentation
- [ ] POSIX compliance where appropriate

**Expected Validations:**
- validate-tca-patterns.sh: @State in TCA views, missing @ObservableState
- validate-ios-version.sh: @available checks for iOS < 26, #unavailable usage
- check-build-warnings.sh: Compile warnings, deprecations

**Web Research References:**
- iOS pre-commit hooks: https://mokacoding.com/blog/pre-commit-hooks/
- Xcode build scripts: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
- ShellCheck: https://www.shellcheck.net/
```

---

### Prompt 3.2: Validation Script Effectiveness

```
Assess how effectively validation scripts enforce project conventions.

**Context:**
- Project has zero-tolerance rules that MUST be enforced
- Scripts should catch violations before commit
- Convention violations have caused production issues

**Files to Analyze:**
- Scripts/validate-tca-patterns.sh
- Scripts/validate-ios-version.sh
- AGENTS.md (conventions to validate)
- CLAUDE.md (critical rules)

**Zero-Tolerance Rules (from AGENTS.md):**
1. No @State/@StateObject in TCA views
2. @DependencyClient required for all services
3. Delegate actions for parent communication
4. iOS 26+ only - no backwards compatibility

**Questions to Answer:**
1. Does validate-tca-patterns.sh catch all TCA violations?
   - @State in TCA views
   - Missing @ObservableState
   - Missing @DependencyClient
   - Direct service instantiation
2. Does validate-ios-version.sh catch all backwards-compat code?
   - @available checks for iOS < 26
   - #unavailable usage
   - if #available fallbacks
3. What conventions are NOT validated by scripts?
4. Are there false positives/negatives?

**Missing Validations to Consider:**
- Delegate action usage for parent communication
- Cancel ID presence for async operations
- testValue implementations for dependency clients
- API key header usage (should be query param)

**Recommended Script Enhancements:**
```bash
# Validate delegate actions exist for child features
grep -r "case .delegate" App/Features/*.swift

# Validate Cancel IDs for async effects
grep -r "CancelID" App/Features/*.swift

# Validate no API key in headers
grep -r "X-API-Key" App/Dependencies/*.swift
```

**Web Research References:**
- SwiftLint pre-commit: https://medium.com/@rygel/swiftlint-on-autopilot-in-xcode-enforce-code-conventions-with-git-pre-commit-hooks-and-automation-52c5eb4d5454
```

---

### Prompt 3.3: CI/CD Script Integration

```
Evaluate CI/CD workflow and script integration.

**Context:**
- GitHub Actions used for CI/CD
- Dependabot configured for dependency updates
- Unit tests currently disabled in CI due to crash

**Files to Analyze:**
- .github/workflows/tests.yml
- .github/dependabot.yml
- Scripts/*.sh (all scripts)
- .claude/commands/*.md (Claude command definitions)

**Current CI Status (from IMPROVEMENT_PLAN.md):**
- Unit tests: DISABLED (host app crash)
- UI tests: Running
- Build: Working
- Artifacts: Preserved

**Questions to Answer:**
1. Are all validation scripts run in CI?
2. Is the workflow efficient (parallel jobs, caching)?
3. Are artifacts properly preserved?
4. Is Dependabot configuration appropriate?
5. What automation is missing from CI/CD?

**Missing CI/CD Opportunities:**
- [ ] SwiftLint/SwiftFormat enforcement
- [ ] Code coverage reporting (Codecov)
- [ ] Mutation testing (Muter)
- [ ] Release automation
- [ ] Changelog generation
- [ ] Version bumping
- [ ] App Store deployment

**Recommended CI Improvements:**
```yaml
# Add script validations to CI
- name: Validate TCA Patterns
  run: ./Scripts/validate-tca-patterns.sh

- name: Validate iOS Version
  run: ./Scripts/validate-ios-version.sh

- name: Upload Coverage
  uses: codecov/codecov-action@v4
```

**Web Research References:**
- GitHub Actions iOS CI/CD 2025: https://ravi6997.medium.com/ci-cd-pipelines-for-ios-backend-a-practical-guide-for-mobile-devops-in-2025-d3a4440ee46d
- Fastlane + GitHub Actions: https://www.runway.team/blog/how-to-set-up-a-ci-cd-pipeline-for-your-ios-app-fastlane-github-actions
```

---

## 4. Dependencies Evaluation Prompts

### Prompt 4.1: Version Currency Assessment

```
Evaluate whether all SPM dependencies are current and secure.

**Context:**
- Project uses Swift Package Manager
- TCA ecosystem from Point-Free
- OpenAPI tooling from Apple
- Valet from Square

**Files to Analyze:**
- OfflineMediaDownloader.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
- APITypes/Package.swift
- APITypes/Package.resolved

**Current Dependencies (from IMPROVEMENT_PLAN.md):**
| Dependency | Current Version | Purpose |
|------------|-----------------|---------|
| swift-composable-architecture | 1.22.2+ | TCA framework |
| Valet | 4.3.0 | Keychain storage |
| swift-openapi-runtime | 1.9.0 | OpenAPI client |
| swift-openapi-urlsession | 1.2.0 | URLSession transport |
| swift-openapi-generator | 1.10.3 | Code generation |
| swift-snapshot-testing | Latest | Snapshot tests |

**Questions to Answer:**
1. Are all packages at their latest stable versions?
2. Are there any security advisories for current versions?
3. Is the Point-Free ecosystem version-aligned (TCA, dependencies, case-paths)?
4. Are there deprecated packages that need replacement?
5. What breaking changes exist in newer versions?

**Version Check Commands:**
```bash
# Check for outdated packages
swift package show-dependencies

# Check TCA releases
gh release list -R pointfreeco/swift-composable-architecture

# Check Valet releases
gh release list -R square/Valet
```

**Web Research References:**
- SPM best practices 2025: https://medium.com/@bhumibhuva18/swift-package-manager-dependency-management-practical-guide-for-ios-developers-040638ca2b3c
- SPM security features: https://commitstudiogs.medium.com/whats-new-in-swift-package-manager-spm-for-2025-d7ffff2765a2
```

---

### Prompt 4.2: Dependency Usage Analysis

```
Identify unused or underutilized dependencies.

**Context:**
- 20+ total packages (direct + transitive)
- TCA ecosystem has many interconnected packages
- OpenAPI generator produces typed clients

**Files to Analyze:**
- All App/**/*.swift files (import statements)
- Package.resolved (full dependency list)
- APITypes/Package.swift (OpenAPI dependencies)

**Questions to Answer:**
1. Are all direct dependencies actively used?
2. Are there features of dependencies not being leveraged?
3. Could any dependencies be removed?
4. Are there duplicate functionalities across dependencies?

**Analysis Method:**
```bash
# Find all imports
grep -r "^import " App/**/*.swift | sort | uniq -c

# Check for TCA feature usage
grep -r "@Shared" App/**/*.swift  # Should be used but isn't
grep -r "IdentifiedArray" App/**/*.swift  # Should be widespread
```

**TCA Features to Evaluate Usage:**
- [ ] @Shared state (recommended in IMPROVEMENT_PLAN.md)
- [ ] IdentifiedArray (should be used for collections)
- [ ] @PresentationState (for navigation)
- [ ] Effect.run vs Effect.task
- [ ] withDependencies (for testing)

**Potential Optimizations:**
- Remove unused transitive dependencies
- Consolidate similar functionality
- Upgrade to use newer TCA features

**Web Research References:**
- SPM dependency management: https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/
```

---

### Prompt 4.3: Security & License Compliance

```
Audit dependencies for security and license compliance.

**Context:**
- App handles sensitive data (auth tokens, user files)
- Uses Secure Enclave via Valet
- No formal security audit has been conducted

**Files to Analyze:**
- Package.resolved (all dependencies)
- App/Dependencies/KeychainClient.swift (Valet usage)
- App/Dependencies/CertificatePinning.swift (if exists)
- App/Dependencies/ServerClient.swift (API communication)

**Questions to Answer:**
1. Are all licenses compatible with project use?
2. Are there any GPL/LGPL dependencies requiring disclosure?
3. Are there known vulnerabilities in any dependency?
4. Is Valet (keychain) properly configured for security?
5. Are OpenAPI-generated types properly secured?

**License Inventory Required:**
| Package | License | Compatible | Notes |
|---------|---------|------------|-------|
| TCA | MIT | Yes | Point-Free |
| Valet | Apache 2.0 | Yes | Square |
| OpenAPI tools | Apache 2.0 | Yes | Apple |

**Security Considerations (from IMPROVEMENT_PLAN.md):**
- Valet + Secure Enclave: Implemented
- Certificate pinning: NOT implemented (recommended)
- Jailbreak detection: NOT implemented (low priority)
- Code obfuscation: NOT implemented (low priority)

**Security Checklist:**
- [ ] Valet configured with Secure Enclave
- [ ] No sensitive data in logs
- [ ] Proper token handling
- [ ] HTTPS enforced (ATS)
- [ ] Certificate pinning implemented

**Web Research References:**
- OWASP Mobile Security: https://cheatsheetseries.owasp.org/cheatsheets/Mobile_Application_Security_Cheat_Sheet.html
- iOS Security Checklist 2025: https://mobisoftinfotech.com/resources/blog/app-security/ios-app-security-checklist-best-practices
- OWASP MASTG: https://www.aptive.co.uk/blog/owasp-mastg/
```

---

## 5. Architecture Evaluation Prompts

### Prompt 5.1: TCA Pattern Compliance

```
Audit TCA pattern compliance across all features.

**Context:**
- TCA 1.22.2+ requires specific patterns
- Project has strict conventions in AGENTS.md
- 11 features, 15 dependency clients

**Files to Analyze:**
- App/Features/*.swift (11 feature files)
- App/Views/*.swift (SwiftUI views with TCA)
- App/Dependencies/*.swift (15 dependency clients)

**Feature Hierarchy (from AGENTS.md):**
```
RootFeature (launch, auth routing)
├── LoginFeature (Sign in with Apple)
└── MainFeature (TabView container)
    ├── FileListFeature
    │   └── FileCellFeature[] (per-file downloads)
    └── DiagnosticFeature (debug/keychain)
```

**TCA Compliance Checklist:**
- [ ] @Reducer macro on all feature structs
- [ ] @ObservableState on all State structs
- [ ] No @State/@StateObject in TCA views
- [ ] @Bindable var store: StoreOf<Feature> pattern
- [ ] Delegate actions for parent-child communication
- [ ] CancelID enum for async operations
- [ ] liveValue + testValue for all dependencies

**Questions to Answer:**
1. Which features violate TCA conventions?
2. Are Scope() reducers properly composed?
3. Is IdentifiedArray used for child collections?
4. Are effects properly cancellable?
5. Is state shared appropriately between features?

**Known Issues (from IMPROVEMENT_PLAN.md):**
- FileCellFeature + FileDetailFeature: ~150 lines duplicate download logic
- No @Shared state mechanism used (recommended)
- Tight coupling between LoginFeature and MainFeature

**Web Research References:**
- TCA Performance: https://www.swiftyplace.com/blog/the-composable-architecture-performance
- TCA Trade-offs: https://hackernoon.com/the-composable-architecture-strengths-trade-offs-and-performance-tips
- Modern iOS Architecture 2025: https://medium.com/@csmax/the-ultimate-guide-to-modern-ios-architecture-in-2025-9f0d5fdc892f
```

---

### Prompt 5.2: Security Implementation Audit

```
Audit security implementation across the application.

**Context:**
- App uses Sign in with Apple for authentication
- JWT tokens stored in keychain
- API key sent as query parameter (critical convention)
- AWS backend with API Gateway

**Files to Analyze:**
- App/Dependencies/KeychainClient.swift (Valet usage)
- App/Dependencies/ServerClient.swift (API communication)
- App/Dependencies/CertificatePinning.swift (if exists)
- App/Dependencies/APIKeyMiddleware.swift
- Development.xcconfig (secrets handling)

**Security Checklist (OWASP Mobile):**
- [ ] Sensitive data stored in Keychain (not UserDefaults)
- [ ] Certificate pinning implemented
- [ ] API key not hardcoded (uses xcconfig)
- [ ] No sensitive data in logs
- [ ] Proper authentication token handling
- [ ] HTTPS enforced (ATS)
- [ ] Token refresh before expiration

**Critical Convention (from CLAUDE.md):**
```swift
// ✅ CORRECT - Query parameter
request.path = "\(currentPath)?ApiKey=\(apiKey)"

// ❌ WRONG - Header (DO NOT USE)
request.headerFields["X-API-Key"] = apiKey
```

**Questions to Answer:**
1. Is Valet configured with Secure Enclave?
2. Is certificate pinning properly implemented?
3. Are tokens refreshed before expiration (proactive refresh)?
4. Is debug code stripped from release builds?
5. Are Shortcuts/Siri integrations secured?

**Security Grade (from IMPROVEMENT_PLAN.md):**
| Measure | Implementation | Assessment |
|---------|----------------|------------|
| Keychain storage | Valet + Secure Enclave | Excellent |
| JWT handling | Stored in keychain | Good |
| HTTPS | Required | Good |
| API key protection | xcconfig | Good |
| Certificate pinning | Not implemented | Missing |

**Web Research References:**
- iOS Security Checklist 2025: https://mobisoftinfotech.com/resources/blog/app-security/ios-app-security-checklist-best-practices
- OWASP Mobile Top 10: https://medium.com/@paresh.karnawat/owasp-mobile-top-10-2024-a-complete-guide-for-ios-developers-with-best-practices-tools-7f5ae0659bdf
```

---

### Prompt 5.3: Performance & Optimization Analysis

```
Identify performance optimization opportunities.

**Context:**
- TCA can have performance implications at scale
- Large file lists need efficient rendering
- Background downloads need proper management
- CoreData concurrency is a known issue

**Files to Analyze:**
- App/Features/FileListFeature.swift (list performance)
- App/Features/FileCellFeature.swift (cell rendering)
- App/Dependencies/DownloadClient.swift (download performance)
- App/Dependencies/CoreDataClient.swift (database performance)

**Performance Areas to Evaluate:**
1. State observation granularity (view scoping)
2. List rendering (IdentifiedArray efficiency)
3. Image/media loading (lazy loading)
4. CoreData query efficiency
5. Download concurrency management

**Known Issues (from IMPROVEMENT_PLAN.md):**
- CoreData: `cacheFiles` uses `viewContext.perform` for writes (causes scroll stutter)
- Download progress observations: NSKeyValueObservation cleanup risk
- Image memory: No caching implemented

**Questions to Answer:**
1. Are views observing minimal state slices?
2. Is ForEach using proper identity?
3. Are large lists using lazy loading?
4. Are expensive computations memoized?
5. Is CoreData properly using background contexts?

**Performance Recommendations:**
```swift
// Use background context for writes
let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

// Use NSBatchInsertRequest for bulk operations
let batchInsert = NSBatchInsertRequest(entity: entity, objects: objects)
```

**Web Research References:**
- TCA Performance optimization: https://www.swiftyplace.com/blog/the-composable-architecture-performance
- SwiftUI best practices 2025: https://toxigon.com/swiftui-best-practices-2025
```

---

### Prompt 5.4: Code Organization Review

```
Review code organization and identify improvement opportunities.

**Context:**
- Project follows TCA conventions from AGENTS.md
- Clear separation: Features → Views → Dependencies → Models
- 30+ wiki documentation files

**Files to Analyze:**
- App/ directory structure
- All feature and view files
- IMPROVEMENT_PLAN.md (existing evaluation)

**Current Structure (from AGENTS.md):**
```
App/
├── Features/           # TCA Reducers
├── Views/              # SwiftUI Views
├── Dependencies/       # Dependency Clients
├── Models/             # Data models + Mappers
├── Enums/              # Shared enumerations
├── Extensions/         # Swift extensions
├── DesignSystem/       # Theme, Components
├── Helpers/            # TestHelper
└── LiveActivity/       # Download activity
```

**Organization Criteria:**
- Feature files properly scoped
- Views separated from reducers
- Dependencies properly isolated
- Models appropriately structured
- No circular dependencies

**Questions to Answer:**
1. Are files in the correct directories per conventions?
2. Is there code duplication between features?
3. Are there overly large files that should be split?
4. Is the dependency graph clean (no cycles)?
5. Could any code be extracted to shared utilities?

**Known Duplication (from IMPROVEMENT_PLAN.md):**
- FileCellFeature + FileDetailFeature: ~150 lines download logic
- Date formatting: ~20 lines in File.swift and FileMapper.swift
- Error handling: ~50 lines repeated error-to-AppError conversion

**Output Format:**
| Area | Current | Recommended | Priority |
|------|---------|-------------|----------|
| Download logic | Duplicated | Extract DownloadFeature | High |
| Error handling | Scattered | Consolidate in AppError | Medium |
| Date formatting | Duplicated | Extract to extension | Low |
```

---

## 6. Additional Evaluation Prompts

### Prompt 6.1: OpenAPI Integration Quality

```
Evaluate the OpenAPI type generation and integration.

**Context:**
- OpenAPI spec generated from TypeSpec in backend repo
- swift-openapi-generator produces typed clients
- Mappers convert API types to domain models
- Spec sync script maintains consistency

**Files to Analyze:**
- APITypes/Package.swift
- APITypes/Sources/APITypes/openapi.yaml
- APITypes/openapi-generator-config.yaml
- App/Models/Mappers/*.swift
- Scripts/sync-openapi.sh

**Critical Convention (from CLAUDE.md):**
```
The OpenAPI spec is generated from TypeSpec in the backend repo and synced here:
- Source: aws-cloudformation-media-downloader/docs/api/openapi.yaml
- Target: APITypes/Sources/APITypes/openapi.yaml
- Sync script: ./Scripts/sync-openapi.sh

Do NOT manually edit the openapi.yaml - fix issues in the backend TypeSpec definitions.
```

**Questions to Answer:**
1. Is the OpenAPI spec up-to-date with backend?
2. Are mappers comprehensive and type-safe?
3. Is error handling at API boundaries complete?
4. Is the sync script reliable?
5. Are all API endpoints properly typed?

**Mapper Quality Checklist:**
- [ ] All API response types have domain model mappers
- [ ] Nullable fields handled properly
- [ ] Date parsing consistent
- [ ] Error responses mapped to AppError
- [ ] Validation at boundaries

**Web Research References:**
- swift-openapi-generator: https://github.com/apple/swift-openapi-generator
- Spec-driven development: https://swiftinit.org/docs/swift-openapi-generator/swift_openapi_generator/practicing-spec-driven-api-development
```

---

### Prompt 6.2: CoreData & Persistence Review

```
Evaluate CoreData integration and persistence patterns.

**Context:**
- CoreData used for local file persistence
- Known concurrency issue: writes on main thread
- Upsert pattern documented in wiki

**Files to Analyze:**
- App/Dependencies/CoreDataClient.swift
- App/Persistence.swift (if exists)
- OfflineMediaDownloader.xcdatamodeld (Core Data model)
- Docs/wiki/Infrastructure/CoreData-Integration.md

**Questions to Answer:**
1. Is CoreData concurrency handled correctly?
2. Are migrations properly configured?
3. Is the cache invalidation strategy sound?
4. Are batch operations optimized?
5. Is data persistence TCA-compliant?

**Known Issue (from IMPROVEMENT_PLAN.md):**
```swift
// Current: writes on viewContext (main thread)
// Risk: Writing hundreds of files causes scroll stutter
// Fix: Use background context
let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
```

**Concurrency Considerations:**
- Background context usage
- Main actor constraints
- Conflict resolution (NSMergeByPropertyObjectTrumpMergePolicy)
- Notification observation for context changes

**Batch Operation Optimization:**
```swift
// For bulk inserts, use NSBatchInsertRequest
let batchInsert = NSBatchInsertRequest(entity: entity, objects: objects)
batchInsert.resultType = .objectIDs
```

**Web Research References:**
- CoreData concurrency: https://developer.apple.com/documentation/coredata/using_core_data_in_the_background
- NSBatchInsertRequest: https://developer.apple.com/documentation/coredata/nsbatchinsertrequest
```

---

### Prompt 6.3: Push Notification & Background Processing

```
Evaluate push notification and background processing implementation.

**Context:**
- AWS SNS sends push notifications
- Background downloads via URLSession
- Live Activities for download progress
- Critical issue: background session reconnection missing

**Files to Analyze:**
- App/OfflineMediaDownloaderApp.swift
- App/AppDelegate.swift
- App/Dependencies/NotificationClient.swift
- App/Dependencies/DownloadClient.swift
- App/LiveActivity/*.swift

**Questions to Answer:**
1. Is push notification routing complete?
2. Are background downloads properly configured?
3. Is the Live Activity implementation correct?
4. Are notification payloads handled securely?
5. Is background session management robust?

**Critical Issue (from IMPROVEMENT_PLAN.md):**
```swift
// MISSING in AppDelegate - causes "zombie" downloads
func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
) {
    Task {
        await DownloadManager.shared.setBackgroundCompletionHandler(completionHandler)
    }
}
```

**Background Download Checklist:**
- [ ] Background URLSession configured
- [ ] handleEventsForBackgroundURLSession implemented
- [ ] Completion handler stored and called
- [ ] Downloads resume after app termination
- [ ] Progress updates via NSKeyValueObservation

**Push Notification Flow (from AGENTS.md):**
```
Push Notification → AppDelegate → RootFeature → MainFeature.FileListFeature
                                                      │
                                                      ↓
                                          FileCellFeature[] → UI
```

**Web Research References:**
- URLSession Background Downloads: https://www.avanderlee.com/swift/urlsession-common-pitfalls-with-background-download-upload-tasks/
- iOS Background Survival Guide: https://medium.com/@melissazm/ios-18-background-survival-guide-part-3-unstoppable-networking-with-background-urlsession-f9c8f01f665b
```

---

## Verification Steps

After running evaluation prompts, verify findings with these commands:

### 1. Run Validation Scripts
```bash
./Scripts/validate-tca-patterns.sh
./Scripts/validate-ios-version.sh
./Scripts/check-build-warnings.sh
```

### 2. Run Test Suite
```bash
xcodebuild -project OfflineMediaDownloader.xcodeproj \
  -scheme OfflineMediaDownloader \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  test
```

### 3. Check Dependency Versions
```bash
swift package show-dependencies
swift package update --dry-run
```

### 4. Review CI Results
```bash
gh run list --workflow=tests.yml --limit=5
```

---

## Summary

This document contains **22 structured evaluation prompts** covering:

| Category | Prompts | Focus Areas |
|----------|---------|-------------|
| Testing | 5 | Coverage, TestStore, fixtures, mutation, CI |
| Documentation | 4 | Structure, accuracy, ADRs, DocC |
| Scripts | 3 | Quality, effectiveness, CI integration |
| Dependencies | 3 | Versions, usage, security/licenses |
| Architecture | 4 | TCA compliance, security, performance, organization |
| Additional | 3 | OpenAPI, CoreData, notifications |

Each prompt includes:
- Context from AGENTS.md and IMPROVEMENT_PLAN.md
- Specific files to analyze
- Detailed questions to answer
- Web research references for industry standards
- Output format recommendations

**Usage**: Copy individual prompts into Claude sessions for focused evaluation of specific areas.
