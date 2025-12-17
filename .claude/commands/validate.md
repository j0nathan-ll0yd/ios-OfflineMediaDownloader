# Full Validation Suite

Run all validation checks on the OfflineMediaDownloader codebase.

## Checks to Run

### 1. iOS Version Requirements
Check for forbidden backwards compatibility patterns:
```bash
Scripts/validate-ios-version.sh
```

Forbidden patterns:
- `@available(iOS X, *)` where X < 26
- `#available(iOS X, *)` where X < 26
- `#unavailable(iOS ...)`

### 2. TCA Pattern Compliance
Check for TCA convention violations:
```bash
Scripts/validate-tca-patterns.sh
```

Zero-tolerance violations:
- `@State` in TCA views (files containing `StoreOf`)
- `@StateObject` in TCA views
- `@ObservedObject` in TCA views

### 3. Build Warnings
Run a full build and check for compiler warnings:
```bash
Scripts/check-build-warnings.sh
```

### 4. Fix Any Violations Found
For each violation:
1. Read the file
2. Apply the fix per project conventions
3. Re-run validation to confirm

## Summary
Report total violations found and fixed.
