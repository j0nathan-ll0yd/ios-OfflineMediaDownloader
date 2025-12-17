# Build and Fix Warnings

Build the OfflineMediaDownloader project and fix any warnings that appear.

## Workflow

1. **Run the build check script:**
```bash
Scripts/check-build-warnings.sh
```

2. **If warnings are found:**
   - Read each file with warnings
   - Analyze the warning message
   - Apply the appropriate fix
   - Re-run build to verify

3. **Common warning fixes:**
   - `no 'async' operations occur within 'await'` → Mark function as `async`
   - `immutable value was never used` → Remove or use the value
   - `result of call is unused` → Assign to `_` or use the result
   - `deprecated` → Use the recommended replacement API

4. **Report summary** of warnings fixed
