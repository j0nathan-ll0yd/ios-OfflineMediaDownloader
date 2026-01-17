# iOS OfflineMediaDownloader - Comprehensive Health Check

You are performing a comprehensive health check of this iOS TCA codebase. This is a
revisit/maintenance pass - many areas are already well-maintained. Your job is to:

1. **Quickly verify** each area is still in good shape
2. **Flag any drift** from documented patterns or new issues
3. **Skip deep analysis** for areas that look healthy
4. **Deep-dive only** into areas showing problems

## Execution Strategy

**USE SUB-AGENTS AGGRESSIVELY.** This codebase is small enough to analyze comprehensively.
Launch multiple sub-agents in parallel to maximize efficiency:

- Use `subagent_type=Explore` for codebase exploration and pattern discovery
- Use `subagent_type=humanlayer:codebase-analyzer` for detailed component analysis
- Use `subagent_type=humanlayer:codebase-pattern-finder` for finding similar implementations

**Parallelization approach:**
- Launch sub-agents for sections 1-5 in parallel
- Launch sub-agents for sections 6-10 in parallel
- Read ALL files in each area - the codebase is small

## Output Format

For each section, output one of:
- ✅ **HEALTHY** - Brief confirmation (1-2 sentences) if nothing notable
- ⚠️ **NEEDS ATTENTION** - Specific findings with file:line references and priority
- 🔴 **CRITICAL** - Immediate action required

---

## 1. TESTING INFRASTRUCTURE

**Files to Read (ALL):**
- ALL test files: `OfflineMediaDownloaderTests/*.swift`
- ALL UI test files: `OfflineMediaDownloaderUITests/*.swift`
- `OfflineMediaDownloaderTests/TestData.swift`
- Wiki: `Docs/wiki/Testing/TestStore-Usage.md`
- Wiki: `Docs/wiki/Testing/Dependency-Mocking.md`
- Wiki: `Docs/wiki/Testing/Swift-Testing-Patterns.md`
- `.github/workflows/tests.yml`

**Verify:**
- Do ALL tests use Swift Testing framework (`@Test`, `#expect`) not XCTest?
- Do ALL TCA tests use `TestStore` properly with `withDependencies`?
- Are ALL dependency clients mocked appropriately?
- Is `@MainActor` applied to async test functions?
- Does CI run tests successfully on iOS 18+ simulators?
- Are test timeouts reasonable?
- Is test coverage adequate for ALL features?

**Red Flags:** XCTest usage instead of Swift Testing, missing `@MainActor` on async tests,
              direct dependency instantiation in tests, unmocked dependencies,
              tests that mutate state outside `store.send { }` closures.

**Sub-agent suggestion:** Launch one agent to validate unit tests, another for CI workflow analysis.

---

## 2. DOCUMENTATION SYSTEM

**Files to Read (ALL):**
- `AGENTS.md`, `CLAUDE.md`
- `Docs/conventions-tracking.md`
- ALL wiki files: `Docs/wiki/**/*.md` (28 files total)
- `.claude/commands/*.md`
- `README.md`
- `IMPROVEMENT_PLAN.md`

**Verify:**
- Does AGENTS.md reflect current codebase state (iOS 26+, TCA 1.22.2+)?
- Are ALL wiki pages cross-referenced correctly (no broken links)?
- Does conventions-tracking.md match reality (documented conventions)?
- Are emerging conventions being captured in `Docs/wiki/Meta/Emerging-Conventions.md`?
- Is the Feature Implementation Checklist current?
- Are .claude/commands covering common workflows?

**Red Flags:** Stale documentation (wrong iOS version, outdated patterns), broken wiki links,
              conventions not in tracking file, missing documentation for new features.

**Sub-agent suggestion:** Launch one agent for wiki validation, another for AGENTS.md accuracy check.

---

## 3. TCA ARCHITECTURE

**Files to Read (ALL):**
- ALL Feature reducers: `App/Features/*.swift` (6 files)
- ALL Views: `App/Views/*.swift`
- Wiki: `Docs/wiki/TCA/*.md` (7 files)
- Wiki: `Docs/wiki/Views/*.md` (4 files)

**Verify:**
- Do ALL reducers use `@Reducer` macro?
- Do ALL State structs have `@ObservableState`?
- Are delegate actions used for parent communication (no NotificationCenter)?
- Do ALL async effects have `CancelID` enum and `.cancellable()` modifier?
- Are child features scoped correctly with `Scope(state:action:)`?
- Are `IdentifiedArrayOf` used for collections of child features?
- Is the feature hierarchy documented accurately (Root > Main > FileList/Diagnostic)?

**Zero-Tolerance Violations (run script):**
```bash
Scripts/validate-tca-patterns.sh
```
- No `@State` in TCA views (files containing `StoreOf`)
- No `@StateObject` in TCA views
- No `@ObservedObject` in TCA views

**Red Flags:** Missing `@ObservableState`, async effects without cancel IDs,
              direct parent state mutation, NotificationCenter usage.

**Sub-agent suggestion:** Launch parallel agents for: Feature reducers and View integration.

---

## 4. SHELL SCRIPTS (Scripts/)

**Files to Read (ALL):**
- `Scripts/validate-tca-patterns.sh`
- `Scripts/validate-ios-version.sh`
- `Scripts/check-build-warnings.sh`
- `Scripts/sync-openapi.sh`
- `Scripts/setup-hooks.sh`
- `Scripts/extract_screenshots.py`
- `.githooks/` directory (if exists)

**Verify:**
- Do ALL shell scripts use `set -euo pipefail`?
- Is `validate-tca-patterns.sh` catching all zero-tolerance violations?
- Is `validate-ios-version.sh` checking for iOS < 26 compatibility code?
- Is `check-build-warnings.sh` finding the correct simulator?
- Does `sync-openapi.sh` properly sync with backend API?
- Are git hooks set up via `setup-hooks.sh`?

**Red Flags:** Missing error handling, shellcheck violations, hardcoded paths,
              scripts that don't exit on error, outdated iOS version checks.

**Sub-agent suggestion:** Single agent can handle all scripts comprehensively.

---

## 5. DEPENDENCIES (SPM)

**Files to Read (ALL):**
- Xcode project's `Package.resolved` (search in .xcodeproj)
- `APITypes/Package.swift`
- `APITypes/Package.resolved` (if exists)
- `.github/dependabot.yml`

**Verify:**
- Is TCA pinned to compatible version (currently 1.22.2+)?
- Is Valet version current for Secure Enclave support?
- Are ALL Point-Free dependencies at compatible versions?
- Is Dependabot configured for weekly updates?
- Are there any known vulnerabilities in dependencies?
- Is swift-openapi-generator current for API type generation?
- Are transitive dependencies reasonable (no unexpected packages)?

**Security Checks:**
- Check for known CVEs in dependencies
- Verify no deprecated packages are in use
- Confirm dependency versions are recent (within 6 months)

**Red Flags:** Unpinned critical dependencies, outdated packages with CVEs,
              version conflicts between TCA ecosystem packages,
              missing Dependabot configuration.

**Sub-agent suggestion:** Single agent with focus on security and version compatibility.

---

## 6. AI AGENT HELPERS (.claude/, AGENTS.md)

**Files to Read (ALL):**
- `.claude/commands/validate.md`
- `.claude/commands/build.md`
- `.claude/commands/health-check.md` (this file)
- `AGENTS.md`
- `CLAUDE.md`
- `.claude/settings.json` (if exists)

**Verify:**
- Do .claude/commands cover validation and build workflows?
- Is AGENTS.md comprehensive (convention capture, templates, checklists)?
- Does CLAUDE.md provide accurate quick-start guidance?
- Are the zero-tolerance rules clearly documented?
- Are the TCA templates accurate and current?
- Is the Feature Implementation Checklist complete?

**Red Flags:** Missing workflow commands, outdated AGENTS.md guidance,
              incorrect TCA templates, missing convention documentation,
              commands that reference non-existent scripts.

**Sub-agent suggestion:** Single agent for AI helper completeness check.

---

## 7. SOURCE CODE ARCHITECTURE

**Files to Read (ALL):**
- ALL Dependency clients: `App/Dependencies/*.swift` (14 files)
- ALL Models: `App/Models/*.swift`
- ALL Enums: `App/Enums/*.swift`
- ALL Extensions: `App/Extensions/*.swift`
- ALL Design System: `App/DesignSystem/**/*.swift`
- `App/Persistence.swift`
- `App/OfflineMediaDownloaderApp.swift`
- `Constants.swift`

**Verify:**
- Do ALL dependency clients use `@DependencyClient` macro?
- Do ALL clients provide both `liveValue` and `testValue`?
- Is vendor encapsulation intact (Valet in KeychainClient, URLSession in DownloadClient)?
- Are naming conventions followed (Models: nouns, Clients: *Client, Views: *View)?
- Is the file organization per wiki/Conventions/File-Organization.md?
- Are logging emoji prefixes used consistently?

**Red Flags:** Direct instantiation of services, missing testValue implementations,
              naming convention violations, scattered file organization,
              hardcoded values that should be in Configuration.

**Sub-agent suggestion:** Launch parallel agents for: Dependencies, Models, and Design System.

---

## 8. SECURITY (Keychain, Info.plist, Secrets)

**Files to Read (ALL):**
- `App/Dependencies/KeychainClient.swift`
- `App/Dependencies/CertificatePinning.swift`
- `App/Dependencies/ServerClient.swift`
- `App/Dependencies/AuthenticationClient.swift`
- `App/Dependencies/APIKeyMiddleware.swift`
- `App/Dependencies/AuthenticationMiddleware.swift`
- `App/Info.plist`
- `Development.xcconfig`
- `Development.xcconfig.example`
- `App/App.entitlements` (if exists)
- Wiki: `Docs/wiki/Infrastructure/Keychain-Storage-Valet.md`

**Verify:**
- Is Valet used correctly with appropriate accessibility level (e.g., `whenUnlocked`)?
- Is `SecureEnclaveValet` used for highly sensitive data where available?
- Are NO secrets hardcoded in code (grep for API keys, tokens, passwords)?
- Does Info.plist reference secrets via xcconfig variables only?
- Is Development.xcconfig in .gitignore?
- Is certificate pinning implemented for API calls?
- Are authentication tokens stored in Keychain (not UserDefaults)?

**Security Scan Commands:**
```bash
# Check for hardcoded secrets
grep -rn "sk_live\|pk_live\|api_key\|secret\|password\|token" App/ --include="*.swift" | grep -v "\.swift:.*//\|KeychainClient\|Token"
```

**Red Flags:** Exposed secrets in code, UserDefaults for sensitive data,
              missing certificate pinning, incorrect Valet accessibility levels,
              committed Development.xcconfig with real values.

**Sub-agent suggestion:** Launch one agent for secrets scanning, another for Keychain/Valet review.

---

## 9. BUILD & BUNDLING (Warnings, Size, Configuration)

**Files to Read (ALL):**
- `Scripts/check-build-warnings.sh`
- `OfflineMediaDownloader.xcodeproj/project.pbxproj` (build settings sections)
- `Development.xcconfig`
- `App/Info.plist`
- `.github/workflows/tests.yml` (build configuration)
- `App/Assets.xcassets/`

**Verify:**
- Are there ZERO build warnings? Run:
  ```bash
  Scripts/check-build-warnings.sh
  ```
- Is "Treat Warnings as Errors" enabled for Release builds?
- Is the deployment target iOS 18.0+ consistently?
- Are unused resources removed (no orphaned images/strings)?
- Is App Thinning enabled?
- Are asset catalogs properly organized?
- Is code signing configured correctly for CI (CODE_SIGNING_ALLOWED=NO)?
- Are Swift 6 settings enabled (strict concurrency)?

**iOS Version Check:**
```bash
Scripts/validate-ios-version.sh
```
- No `@available(iOS X, *)` where X < 26
- No `#available(iOS X, *)` where X < 26
- No `#unavailable(iOS ...)`

**Red Flags:** Build warnings present, inconsistent deployment targets,
              oversized asset bundles, code signing issues in CI,
              deprecated build settings, backwards compatibility code.

**Sub-agent suggestion:** Single agent can run build check and analyze configuration.

---

## 10. SWIFT 6 CONCURRENCY & OBSERVABILITY

**Files to Read (ALL):**
- ALL files with async/await: `App/**/*.swift`
- `App/Dependencies/*.swift` (all `@Sendable` declarations)
- `App/Features/*.swift` (TCA async effects)
- Wiki: `Docs/wiki/TCA/Effect-Patterns.md`
- `App/Dependencies/LoggerClient.swift`
- `App/Dependencies/AnalyticsClient.swift`
- `App/Dependencies/PerformanceClient.swift`
- `App/Dependencies/CorrelationClient.swift`
- `App/Dependencies/CorrelationMiddleware.swift`

**Verify:**
- Are ALL async closures marked `@Sendable`?
- Is `@MainActor` applied correctly to UI-bound code?
- Are there NO data races (enable Xcode Thread Sanitizer if needed)?
- Is strict concurrency checking enabled in build settings?
- Are `@preconcurrency` imports used appropriately for third-party libraries?
- Is logging structured consistently (LoggerClient)?
- Are performance metrics captured (PerformanceClient)?
- Is correlation ID propagation working (CorrelationClient/Middleware)?

**Red Flags:** Missing `@Sendable` on async closures, `@MainActor` violations,
              data race warnings, inconsistent logging patterns,
              missing observability instrumentation.

**Sub-agent suggestion:** Launch one agent for concurrency audit, another for observability review.

---

## EXECUTION APPROACH

1. **Run validation scripts first** for quick signal:
   ```bash
   Scripts/validate-tca-patterns.sh
   Scripts/validate-ios-version.sh
   Scripts/check-build-warnings.sh
   ```
2. **Launch sub-agents in parallel** for independent sections
3. **Read ALL files** in each area - don't sample, be comprehensive
4. **Cross-reference findings** between sections (e.g., security issues in source code)
5. **Aggregate findings** into prioritized action items

## FINAL OUTPUT

Produce a summary table:

| Area | Status | Key Findings | Priority Actions |
|------|--------|--------------|------------------|
| 1. Testing | ✅/⚠️/🔴 | ... | ... |
| 2. Documentation | ✅/⚠️/🔴 | ... | ... |
| 3. TCA Architecture | ✅/⚠️/🔴 | ... | ... |
| 4. Shell Scripts | ✅/⚠️/🔴 | ... | ... |
| 5. Dependencies | ✅/⚠️/🔴 | ... | ... |
| 6. AI Agent Helpers | ✅/⚠️/🔴 | ... | ... |
| 7. Source Architecture | ✅/⚠️/🔴 | ... | ... |
| 8. Security | ✅/⚠️/🔴 | ... | ... |
| 9. Build & Bundling | ✅/⚠️/🔴 | ... | ... |
| 10. Swift 6 Concurrency | ✅/⚠️/🔴 | ... | ... |

Then list ALL specific action items ordered by priority:

### 🔴 CRITICAL (fix immediately)
- ...

### ⚠️ HIGH (fix soon)
- ...

### 📋 MEDIUM (fix when convenient)
- ...

### 💡 LOW (nice to have)
- ...
